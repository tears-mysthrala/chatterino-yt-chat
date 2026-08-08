local json = require("libs/json")
local Logging = require("src.support.logging")
local Clock = require("src.support.clock")
local Backoff = require("src.support.backoff")
local RateLimit = require("src.support.rate_limit")
local ActiveStreams = require("src.state.active_streams")
local Actions = require("src.youtube.actions")
local Continuations = require("src.youtube.continuations")
local Builder = require("src.messages.builder")
local Innertube = require("src.youtube.innertube")
local Adapter = require("src.c2_adapter")
local Validation = require("src.support.validation")
local DeliveryQueue = require("src.support.delivery_queue")
local Health = require("src.support.health")
local I18n = require("src.i18n")

local Polling = {}

local MAX_RESPONSE_BYTES = 4 * 1024 * 1024
local REACTION_WINDOW_MS = 10000

-- video_id -> { errors = n, reactions = { count, window_start } }
local streams = {}

local FATAL_STATUS = {
  [400] = true, -- invalid continuation / malformed request
  [403] = true, -- chat disabled or forbidden
  [404] = true -- stream gone
}

-- Kinds representing new chat items: these get id-based dedupe. Mutations
-- and system events always pass through.
local DEDUPED_KINDS = {
  text_message = true,
  super_chat = true,
  super_sticker = true,
  membership = true,
  membership_gift = true,
  membership_gift_received = true,
  donation = true,
  legacy_paid = true,
  ticker_paid = true,
  ticker_sticker = true,
  ticker_member = true,
  pinned = true,
  poll = true,
  system = true
}

local POLL_UPDATE_WINDOW_MS = 10000
local sync_delay_ms = 0

--- Sets a presentation delay for normalized event batches.
function Polling.set_sync_delay(value)
  sync_delay_ms = math.floor(Validation.clamp_number(value, 0, 30000, 0))
  return sync_delay_ms
end

function Polling.get_sync_delay()
  return sync_delay_ms
end

local function prune_splits(video_id)
  local alive = {}
  for _, split in ipairs(ActiveStreams.get_splits(video_id)) do
    if Adapter.channel(split) then
      alive[#alive + 1] = split
    else
      ActiveStreams.remove_split(video_id, split)
    end
  end
  return alive
end

local function system_to_splits(video_id, text)
  for _, split in ipairs(ActiveStreams.get_splits(video_id)) do
    Adapter.system(split, text)
  end
end

local function finish_stop(video_id, reason)
  if not streams[video_id] then
    return
  end
  streams[video_id] = nil
  if reason == "paused" then
    system_to_splits(video_id, I18n.t("stopped_paused"))
  elseif reason == "removed" then
    system_to_splits(video_id, I18n.t("stopped_removed"))
  elseif reason == "reconfigured" then
    system_to_splits(video_id, I18n.t("stopped_import"))
  else
    system_to_splits(video_id, I18n.t("stopped", { reason = reason }))
  end
  ActiveStreams.cleanup_video(video_id)
  Logging.info("chat_stopped", { video = video_id, reason = reason })
end

local function stop(video_id, reason, drain_queue)
  local entry = streams[video_id]
  if not entry or entry.ending then
    return
  end
  if drain_queue and sync_delay_ms > 0 then
    entry.ending = true
    DeliveryQueue.enqueue(video_id, sync_delay_ms, function()
      finish_stop(video_id, reason)
    end, Adapter.later)
  else
    DeliveryQueue.cancel(video_id)
    finish_stop(video_id, reason)
  end
end

local function schedule(video_id, data, delay_ms)
  Adapter.later(function()
    if streams[video_id] then
      Polling._request(data)
    end
  end, delay_ms)
end

local function retry(data, reason)
  local video_id = data.videoId
  local entry = streams[video_id]
  if not entry then
    return
  end
  entry.errors = entry.errors + 1
  Health.increment("poll_retries")
  entry.last_error = reason
  local delay = Backoff.chat_error_delay(entry.errors)
  entry.next_poll_ms = Clock.now_ms() + math.floor(delay * 1000)
  Logging.rate_limited("warning", "chat-retry:" .. video_id, 30000, 2, "chat_retry",
    { video = video_id, reason = reason, attempt = entry.errors, retry_s = math.floor(delay) })
  schedule(video_id, data, delay * 1000)
end

local function deliver_event(video_id, channel_name, event)
  if type(event) ~= "table" or type(event.kind) ~= "string" then
    return
  end
  if event.kind == "placeholder" then
    -- Emoji reactions/placeholders: coalesce per window instead of flooding.
    local entry = streams[video_id]
    if entry then
      local now = Clock.now_ms()
      local reactions = entry.reactions
      if (now - reactions.window_start) > REACTION_WINDOW_MS then
        if reactions.count > 0 then
          deliver_event(video_id, channel_name,
            { kind = "system", system_text = "✨ " .. reactions.count .. " reactions in the last few seconds" })
        end
        reactions.count = 0
        reactions.window_start = now
      end
      reactions.count = reactions.count + 1
    end
    return
  end
  if DEDUPED_KINDS[event.kind] and event.id and ActiveStreams.seen_message(video_id, event.id) then
    return
  end
  if event.kind == "poll_update" and event.id then
    -- Polls update on every vote batch; throttle to one visible update per
    -- poll per window so results stay current without flooding.
    if not RateLimit.allow("poll:" .. video_id .. ":" .. event.id, POLL_UPDATE_WINDOW_MS, 1) then
      return
    end
  end
  event.channel_name = channel_name
  local splits = ActiveStreams.get_splits(video_id)

  -- Mutations: try in-place update of the original message first; fall
  -- back to an unequivocal system marker (GOAL.md §5).
  if event.kind == "deleted_message" then
    local marker = event.system_text or "Message deleted"
    if not Adapter.replace_by_youtube_id(event.target_message_id, "🗑 " .. marker, splits) then
      Adapter.deliver(Builder.to_chatterino_message(event, true), splits)
    end
    return
  end
  if event.kind == "replaced_message" then
    local replacement = event.replacement
    if replacement and replacement.kind ~= "unknown_event" then
      replacement.channel_name = channel_name
      local ok, spec = pcall(Builder.to_chatterino_message, replacement, true)
      if ok and spec then
        if not Adapter.replace_spec_by_youtube_id(event.target_message_id, spec, splits) then
          Adapter.deliver(spec, splits)
        end
        return
      end
    end
    Adapter.deliver(Builder.to_chatterino_message(event, true), splits)
    return
  end

  local ok, spec = pcall(Builder.to_chatterino_message, event, true)
  if ok and spec then
    Adapter.deliver(spec, splits)
  end
end

local function handle_payload(data, payload)
  local video_id = data.videoId
  local lc = payload.continuationContents and payload.continuationContents.liveChatContinuation
  if type(lc) ~= "table" then
    -- No live chat continuation content: stream ended or chat disabled.
    stop(video_id, "stream_end", true)
    return
  end

  local actions = lc.actions
  local batch = {}
  if type(actions) == "table" then
    for _, action in ipairs(actions) do
      local ok, events = pcall(Actions.from_action, action)
      if ok and type(events) == "table" then
        for _, event in ipairs(events) do
          batch[#batch + 1] = event
        end
      elseif not ok then
        Logging.rate_limited("warning", "action-err:" .. video_id, 60000, 1, "action_processing_error", {})
      end
    end
  end

  if #batch > 0 then
    local deliver_batch = function()
      for _, event in ipairs(batch) do
        deliver_event(video_id, data.channelName, event)
      end
      Health.increment("delivered_batches")
    end
    if sync_delay_ms == 0 and DeliveryQueue.pending(video_id) == 0 then
      deliver_batch()
    else
      DeliveryQueue.enqueue(video_id, sync_delay_ms, deliver_batch, Adapter.later)
    end
  end

  if #prune_splits(video_id) == 0 then
    stop(video_id, "no_splits")
    return
  end

  local cont, err = Continuations.pick(payload, data.poll_limits)
  if err then
    stop(video_id, "no_continuation", true)
    return
  end
  data.continuation = cont.token
  local jitter = (Backoff._random() * 0.15) * cont.timeout_ms
  local entry = streams[video_id]
  if entry then
    entry.last_success_ms = Clock.now_ms()
    entry.last_error = nil
    entry.next_poll_ms = Clock.now_ms() + cont.timeout_ms + jitter
  end
  schedule(video_id, data, cont.timeout_ms + jitter)
end

function Polling._request(data)
  local video_id = data.videoId
  local entry = streams[video_id]
  if not entry then
    return
  end
  if entry.ending then
    return
  end
  if #prune_splits(video_id) == 0 then
    stop(video_id, "no_splits")
    return
  end
  if ActiveStreams.is_in_flight(video_id) then
    -- A previous request is still open; retry shortly instead of piling up.
    schedule(video_id, data, 1000)
    return
  end
  ActiveStreams.set_in_flight(video_id, true)
  Health.increment("poll_requests")

  local request = Adapter.http_post_json(
    Innertube.live_chat_url(data.apiKey),
    Innertube.build_payload(data.clientVersion, data.continuation))

  request:on_success(function(result)
    ActiveStreams.set_in_flight(video_id, false)
    if not streams[video_id] then
      return
    end
    local status = result:status() or 0
    if status >= 400 then
      Health.increment("http_errors")
    end
    if FATAL_STATUS[status] then
      stop(video_id, "http_" .. status, true)
      return
    end
    if status >= 400 then
      retry(data, "http_" .. status)
      return
    end
    local body = result:data()
    if type(body) ~= "string" or #body == 0 then
      retry(data, "empty_response")
      return
    end
    if #body > MAX_RESPONSE_BYTES then
      retry(data, "oversize_response")
      return
    end
    local ok, payload = pcall(json.decode, body)
    if not ok or type(payload) ~= "table" then
      retry(data, "invalid_json")
      return
    end
    streams[video_id].errors = 0
    Health.increment("poll_successes")
    handle_payload(data, payload)
  end)

  request:on_error(function(result)
    ActiveStreams.set_in_flight(video_id, false)
    if not streams[video_id] then
      return
    end
    retry(data, "network")
  end)

  request:execute()
end

--- Starts the single polling loop for a video. Returns false if one is
--- already active for this videoId.
function Polling.start(data)
  local video_id = data.videoId
  if type(video_id) ~= "string" or video_id == "" then
    return false
  end
  if streams[video_id] then
    return false
  end
  streams[video_id] = {
    errors = 0,
    data = data,
    started_ms = Clock.now_ms(),
    last_success_ms = nil,
    last_error = nil,
    next_poll_ms = Clock.now_ms(),
    ending = false,
    reactions = { count = 0, window_start = Clock.now_ms() }
  }
  Logging.info("chat_started", { video = video_id, channel = data.channelName })
  Polling._request(data)
  return true
end

function Polling.stop(video_id, reason)
  stop(video_id, reason or "manual")
end

function Polling.is_active(video_id)
  return streams[video_id] ~= nil
end

function Polling.active_count()
  local n = 0
  for _ in pairs(streams) do
    n = n + 1
  end
  return n
end

function Polling.status()
  local out = {}
  for video_id, entry in pairs(streams) do
    out[#out + 1] = {
      video_id = video_id,
      channel_id = entry.data and entry.data.channelId or nil,
      channel_name = entry.data and entry.data.channelName or nil,
      errors = entry.errors,
      last_error = entry.last_error,
      last_success_ms = entry.last_success_ms,
      next_poll_ms = entry.next_poll_ms,
      queued_batches = DeliveryQueue.pending(video_id),
      ending = entry.ending == true,
      splits = #ActiveStreams.get_splits(video_id)
    }
  end
  table.sort(out, function(a, b) return a.video_id < b.video_id end)
  return out
end

function Polling.stop_by_channel(channel_id, reason)
  local targets = {}
  for video_id, entry in pairs(streams) do
    if entry.data and entry.data.channelId == channel_id then
      targets[#targets + 1] = video_id
    end
  end
  for _, video_id in ipairs(targets) do stop(video_id, reason or "paused") end
  return #targets
end

--- Test/introspection helper.
function Polling._streams()
  return streams
end

-- ---------------------------------------------------------------------------
-- Offline channel monitoring: one timer loop, per-channel backoff
-- (30/60/120/300 s + jitter), a single check per channel regardless of the
-- number of splits, reset when a stream goes live.
-- ---------------------------------------------------------------------------

local Html = require("src.youtube.html")

local offline = {
  next_due = {}, -- channel key -> epoch seconds
  generation = {}, -- invalidates callbacks from removed/reconfigured channels
  running = false
}

local function offline_url(entry)
  if type(entry.channel_id) == "string" and entry.channel_id ~= "" then
    return "https://www.youtube.com/channel/" .. entry.channel_id .. "/live"
  end
  if type(entry.handle) == "string" and entry.handle ~= "" then
    return "https://www.youtube.com/@" .. entry.handle .. "/live"
  end
  return nil
end

local function offline_check(state, persist, key, entry, splits)
  local url = offline_url(entry)
  if not url or not Validation.is_safe_https_youtube(url) then
    return
  end
  local attempts = ActiveStreams.bump_offline_attempt(key)
  local delay = Backoff.offline_attempt_delay(attempts, {
    schedule = state.settings.offline_poll_schedule,
    max_seconds = state.settings.offline_poll_max
  })
  offline.next_due[key] = math.floor(Clock.now_ms() / 1000) + math.floor(delay)
  local generation = offline.generation[key] or 0

  local function still_current()
    return state.channels and state.channels[key] == entry and entry.paused ~= true and
        (offline.generation[key] or 0) == generation
  end

  local request = Adapter.http_get(url)
  request:on_success(function(result)
    if not still_current() then return end
    local status_ok = (result:status() or 0) == 200
    if not status_ok then
      Logging.rate_limited("warning", "offline-http:" .. key, 300000, 1, "offline_http_status",
        { channel = key, status = result:status() })
      return
    end
    local parsed, err = Html.parse_watch_page(result:data())
    if not parsed then
      if err ~= "continuation" then
        Logging.rate_limited("warning", "offline-parse:" .. key, 300000, 1, "offline_parse_issue",
          { channel = key, err = err })
      end
      return
    end
    if parsed.channelId and (not entry.channel_id or entry.channel_id == "") then
      entry.channel_id = parsed.channelId
      persist(state)
    end
    if parsed.channelName and parsed.channelName ~= parsed.channelId then
      entry.display_name = parsed.channelName
    end
    if parsed.continuation and not Polling.is_active(parsed.videoId) then
      ActiveStreams.reset_offline_attempt(key)
      offline.next_due[key] = math.floor(Clock.now_ms() / 1000) + 30
      ActiveStreams.add_stream(parsed.videoId, parsed.channelName, splits)
      Polling.start({
        videoId = parsed.videoId,
        apiKey = parsed.apiKey,
        clientVersion = parsed.clientVersion,
        continuation = parsed.continuation,
        channelId = parsed.channelId,
        channelName = parsed.channelName,
        poll_limits = {
          min_ms = state.settings.chat_poll_min_ms,
          max_ms = state.settings.chat_poll_max_ms,
          fallback_ms = state.settings.chat_poll_fallback_ms
        }
      })
      system_to_splits(parsed.videoId, I18n.t("live"))
      Logging.info("stream_went_live", { channel = key, video = parsed.videoId })
    end
  end)
  request:on_error(function(result)
    if not still_current() then return end
    Logging.rate_limited("warning", "offline-net:" .. key, 300000, 1, "offline_network_issue",
      { channel = key })
  end)
  request:execute()
end

function Polling.invalidate_channel(key)
  offline.generation[key] = (offline.generation[key] or 0) + 1
  offline.next_due[key] = nil
end

function Polling.check_channel_now(state, persist, key)
  local entry = state.channels and state.channels[key]
  if not entry or entry.paused == true then
    return false
  end
  local splits = {}
  for _, split in ipairs(entry.splits or {}) do
    if Adapter.channel(split) then splits[#splits + 1] = split end
  end
  if #splits == 0 then
    return false
  end
  offline.next_due[key] = 0
  offline_check(state, persist, key, entry, splits)
  return true
end

--- One pass over persisted channels; schedules the next pass at the
--- nearest due time across channels (no busy loop, one timer chain).
function Polling.poll_offline_once(state, persist)
  local now = math.floor(Clock.now_ms() / 1000)
  for key, entry in pairs(state.channels or {}) do
    local splits = {}
    for _, split in ipairs(entry.splits or {}) do
      if Adapter.channel(split) then
        splits[#splits + 1] = split
      end
    end
    if #splits > 0 and entry.paused ~= true then
      local due = offline.next_due[key] or 0
      if now >= due then
        offline_check(state, persist, key, entry, splits)
      end
    end
  end
  -- Next wake: nearest pending due across active channels.
  local next_wakeup = 300
  for key, entry in pairs(state.channels or {}) do
    if type(entry) == "table" and entry.paused ~= true and
        type(entry.splits) == "table" and #entry.splits > 0 then
      local due = offline.next_due[key] or now
      local remaining = due - now
      if remaining < next_wakeup then
        next_wakeup = remaining
      end
    end
  end
  local wake_ms = math.floor(math.max(5, next_wakeup) * 1000)
  Adapter.later(function()
    Polling.poll_offline_once(state, persist)
  end, wake_ms)
end

function Polling.start_offline_monitor(state, persist)
  if offline.running then
    return
  end
  offline.running = true
  Adapter.later(function()
    Polling.poll_offline_once(state, persist)
  end, 1000)
end

--- Test helper: wipe every polling loop and offline-monitor state.
function Polling._reset()
  streams = {}
  sync_delay_ms = 0
  DeliveryQueue._reset()
  offline.next_due = {}
  offline.generation = {}
  offline.running = false
end

return Polling
