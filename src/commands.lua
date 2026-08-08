local Logging = require("src.support.logging")
local Url = require("src.youtube.url")
local Html = require("src.youtube.html")
local Polling = require("src.youtube.polling")
local Channels = require("src.state.channels")
local ActiveStreams = require("src.state.active_streams")
local Adapter = require("src.c2_adapter")
local Persistence = require("src.state.persistence")
local Clock = require("src.support.clock")
local Capabilities = require("src.capabilities")
local Health = require("src.support.health")
local I18n = require("src.i18n")

local Commands = {}
local MAX_SYNC_DELAY_MS = 30000

local function sys(ctx, msg)
  Adapter.system(ctx.channel:get_name(), msg)
end

local function channel_label(key, entry)
  return tostring(entry.display_name or entry.handle or entry.channel_id or key)
end

local function show_help(ctx)
  sys(ctx, I18n.t("help"))
end

local function replace_state(state, imported)
  state.schema_version = imported.schema_version
  state.settings = imported.settings
  state.channels = imported.channels
end

local function handle_control(state, persist, ctx, command)
  if command == "help" then
    show_help(ctx)
    return true
  end
  if command == "list" then
    local keys = Channels.iter_active(state)
    if #keys == 0 then
      sys(ctx, I18n.t("no_channels"))
    end
    for _, key in ipairs(keys) do
      local entry = state.channels[key]
      sys(ctx, key .. " · " .. channel_label(key, entry) .. " · " ..
        I18n.t(entry.paused and "state_paused" or "state_active") .. " · " .. tostring(#entry.splits) .. " split(s)")
    end
    return true
  end
  if command == "status" then
    local statuses = Polling.status()
    sys(ctx, tostring(#statuses) .. " stream(s) · delay " .. tostring(Polling.get_sync_delay()) .. " ms")
    for _, item in ipairs(statuses) do
      local next_ms = math.max(0, math.floor(((item.next_poll_ms or Clock.now_ms()) - Clock.now_ms()) / 1000))
      sys(ctx, tostring(item.channel_name or item.video_id) .. " · " .. tostring(item.splits) ..
        " split(s) · " .. I18n.t("queue") .. " " .. tostring(item.queued_batches) ..
        " · " .. I18n.t("next_poll") .. " " .. tostring(next_ms) ..
        " s" .. (item.last_error and (" · error " .. item.last_error) or ""))
    end
    return true
  end
  if command == "config" then
    local caps = Capabilities.detect()
    sys(ctx, "language=" .. I18n.get() .. " · delay=" .. tostring(Polling.get_sync_delay()) .. " ms" ..
      " · GUI=" .. (caps.settings_gui and I18n.t("yes") or "no (API 2.5.5)") ..
      " · images=" .. I18n.t(caps.images and "image_available" or "image_fallback"))
    return true
  end
  if command == "health" then
    local health = Health.snapshot()
    local counters = health.counters
    sys(ctx, "health · uptime " .. tostring(math.floor(health.uptime_ms / 1000)) .. " s" ..
      " · requests " .. tostring(counters.poll_requests or 0) ..
      " · retries " .. tostring(counters.poll_retries or 0) ..
      " · batches " .. tostring(counters.delivered_batches or 0) ..
      " · unknown " .. tostring(counters.unknown_events or 0))
    if ctx.words[3] == "export" then
      local snapshot = { version = "1.2.0", health = health, streams = Polling.status(), capabilities = Capabilities.detect() }
      local ok = Persistence.export_diagnostics(snapshot)
      sys(ctx, ok and "Diagnóstico exportado a data/YT_CHAT.diagnostics.json." or "No se pudo exportar el diagnóstico.")
    end
    return true
  end
  if command == "language" then
    if #ctx.words < 3 then sys(ctx, I18n.t("language", { language = I18n.get() })) return true end
    local selected = tostring(ctx.words[3]):lower()
    if not I18n.set(selected) then sys(ctx, I18n.t("invalid_language")) return true end
    state.settings.language = selected
    persist(state)
    sys(ctx, I18n.t("language", { language = selected }))
    return true
  end
  if command == "export" then
    local ok = Persistence.export_snapshot(state)
    sys(ctx, ok and I18n.t("exported") or I18n.t("export_failed"))
    return true
  end
  if command == "import" then
    local imported, err = Persistence.import_snapshot()
    if not imported then
      sys(ctx, I18n.t("import_failed", { error = err }))
      return true
    end
    for _, item in ipairs(Polling.status()) do Polling.stop(item.video_id, "reconfigured") end
    replace_state(state, imported)
    Polling.set_sync_delay(state.settings.chat_sync_delay_ms)
    I18n.set(state.settings.language)
    persist(state)
    sys(ctx, I18n.t("imported"))
    return true
  end
  if command == "pause" or command == "resume" or command == "remove" then
    local key = Channels.find(state, ctx.words[3])
    if not key then
      sys(ctx, I18n.t("channel_missing"))
      return true
    end
    local entry = state.channels[key]
    if command == "remove" then
      if entry.channel_id then Polling.stop_by_channel(entry.channel_id, "removed") end
      Channels.remove(state, key)
      persist(state)
      sys(ctx, I18n.t("removed", { channel = key }))
    else
      local paused = command == "pause"
      Channels.set_paused(state, key, paused)
      if paused and entry.channel_id then Polling.stop_by_channel(entry.channel_id, "paused") end
      if not paused then Polling.check_channel_now(state, persist, key) end
      persist(state)
      sys(ctx, I18n.t(paused and "paused" or "resumed", { channel = key }))
    end
    return true
  end
  return false
end

local function start_chat(state, parsed, split)
  ActiveStreams.add_stream(parsed.videoId, parsed.channelName, { split })
  local started = Polling.start({
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
  return started
end

local function handle_url(state, persist, ctx, normalized)
  local split = ctx.channel:get_name()
  local request = Adapter.http_get(normalized.canonical)
  request:on_success(function(result)
    if (result:status() or 0) ~= 200 then
      sys(ctx, I18n.t("http_read", { status = result:status() }))
      return
    end
    local parsed, err = Html.parse_watch_page(result:data())
    if not parsed then
      if err == "continuation" then
        sys(ctx, I18n.t("no_chat"))
      else
        sys(ctx, I18n.t("metadata", { error = err }))
      end
      return
    end
    local key, key_err = Channels.add_binding(state, parsed.channelId, normalized.handle, split)
    if key_err then
      sys(ctx, I18n.t("register", { error = key_err }))
      return
    end
    if parsed.channelName then
      Channels.set_display_name(state, key, parsed.channelName)
    end
    persist(state)
    if parsed.continuation then
      if start_chat(state, parsed, split) then
        sys(ctx, I18n.t("connected"))
      else
        sys(ctx, I18n.t("already"))
      end
    else
      sys(ctx, I18n.t("offline"))
    end
    Logging.info("channel_added", { split = split, channel = key })
  end)
  request:on_error(function()
    Logging.warning("url_read_error", { host = "www.youtube.com" })
    sys(ctx, I18n.t("network"))
  end)
  request:execute()
end

function Commands.register(state, persist)
  local c2 = rawget(_G, "c2")
  c2.register_command("/yt-chat", function(ctx)
    if #ctx.words < 2 then
      show_help(ctx)
      return
    end
    if handle_control(state, persist, ctx, ctx.words[2]) then
      return
    end
    if ctx.words[2] == "delay" then
      if #ctx.words < 3 then
        sys(ctx, I18n.t("delay_current", { delay = Polling.get_sync_delay() }))
        return
      end
      local raw = ctx.words[3]
      local delay = type(raw) == "string" and raw:match("^%d+$") and tonumber(raw) or nil
      if not delay or delay > MAX_SYNC_DELAY_MS then
        sys(ctx, I18n.t("delay_invalid"))
        return
      end
      state.settings.chat_sync_delay_ms = Polling.set_sync_delay(delay)
      persist(state)
      sys(ctx, I18n.t("delay_set", { delay = delay }))
      return
    end
    local normalized, err = Url.normalize(ctx.words[2])
    if not normalized then
      sys(ctx, I18n.t("invalid_url", { error = err }))
      return
    end
    handle_url(state, persist, ctx, normalized)
  end)

  local caps = Capabilities.detect()
  if caps.completions then
    c2.register_callback(c2.EventType.CompletionRequested, function(event)
      if not event.full_text_content:match("^/yt%-chat") then
        return { hide_others = false, values = {} }
      end
      local values = { "help", "list", "status", "health", "pause", "resume", "remove", "delay", "language",
        "config", "export", "import" }
      for _, key in ipairs(Channels.iter_active(state)) do values[#values + 1] = key end
      local matches = {}
      local query = tostring(event.query or ""):lower()
      for _, value in ipairs(values) do
        if tostring(value):lower():find(query, 1, true) == 1 then matches[#matches + 1] = value end
      end
      return { hide_others = false, values = matches }
    end)
  end
end

return Commands
