local json = require("libs/json")
local Logging = require("src.support.logging")
local Backoff = require("src.support.backoff")
local ActiveStreams = require("src.state.active_streams")
local Actions = require("src.youtube.actions")
local Continuations = require("src.youtube.continuations")
local Builder = require("src.messages.builder")
local Innertube = require("src.youtube.innertube")

local Polling = {}

local function each_split(video_id, fn)
  local splits = ActiveStreams.get_splits(video_id)
  for _, split in ipairs(splits) do
    local ch = c2 and c2.Channel and c2.Channel.by_name(split) or nil
    if ch then
      fn(ch)
    end
  end
end

local function dispatch_event(video_id, channel_name, event)
  if not event then
    return
  end
  if event.message_id and ActiveStreams.seen_message(video_id, event.message_id) then
    return
  end
  event.channel_name = channel_name
  local msg = Builder.to_chatterino_message(event, true)
  each_split(video_id, function(ch)
    if ch.add_message then
      ch:add_message(msg)
    else
      ch:add_system_message(msg.message_text or "[yt-chat event]")
    end
  end)
end

function Polling.read_chat(data)
  local video_id = data.videoId
  if ActiveStreams.is_in_flight(video_id) then
    return
  end
  ActiveStreams.set_in_flight(video_id, true)
  local request = c2.HTTPRequest.create(c2.HTTPMethod.Post, Innertube.live_chat_url(data.apiKey))
  Innertube.default_headers(request)
  request:set_header("Content-Type", "application/json")
  request:set_payload(Innertube.build_payload(data.clientVersion, data.continuation))
  request:on_success(function(result)
    ActiveStreams.set_in_flight(video_id, false)
    local status = result:status()
    if status >= 400 then
      local delay = Backoff.chat_error_delay(1, result:header("Retry-After"))
      Logging.warning("chat_http_error", { status = status, video = video_id, retry_s = delay })
      c2.later(function() Polling.read_chat(data) end, math.floor(delay * 1000))
      return
    end
    local ok, payload = pcall(json.decode, result:data())
    if not ok or type(payload) ~= "table" then
      local delay = Backoff.chat_error_delay(1)
      Logging.warning("chat_invalid_json", { video = video_id, retry_s = delay })
      c2.later(function() Polling.read_chat(data) end, math.floor(delay * 1000))
      return
    end
    local actions = payload.continuationContents and payload.continuationContents.liveChatContinuation and
        payload.continuationContents.liveChatContinuation.actions or {}
    for _, action in ipairs(actions) do
      dispatch_event(video_id, data.channelName, Actions.from_action(action))
    end
    local cont, err = Continuations.pick(payload)
    if err then
      Logging.info("chat_stopped", { reason = err, video = video_id })
      return
    end
    data.continuation = cont.token
    c2.later(function()
      Polling.read_chat(data)
    end, math.floor(cont.timeout_ms))
  end)
  request:on_error(function(result)
    ActiveStreams.set_in_flight(video_id, false)
    local delay = Backoff.chat_error_delay(1)
    Logging.warning("chat_network_error", { video = video_id, error = result:error(), retry_s = delay })
    c2.later(function() Polling.read_chat(data) end, math.floor(delay * 1000))
  end)
  request:execute()
end

return Polling
