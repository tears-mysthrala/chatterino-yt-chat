local Validation = require("src.support.validation")
local Logging = require("src.support.logging")
local Url = require("src.youtube.url")
local Html = require("src.youtube.html")
local Innertube = require("src.youtube.innertube")
local Polling = require("src.youtube.polling")
local Channels = require("src.state.channels")
local ActiveStreams = require("src.state.active_streams")

local Commands = {}

local function sys(channel, msg)
  channel:add_system_message("[yt-chat] " .. msg)
end

function Commands.register(state, persist)
  c2.register_command("/yt-chat", function(ctx)
    local channel = ctx.channel
    if #ctx.words < 2 then
      sys(channel, "Usage: /yt-chat https://www.youtube.com/...")
      return
    end
    local normalized, err = Url.normalize(ctx.words[2])
    if err then
      sys(channel, "URL inválida o no permitida (solo HTTPS en hosts oficiales de YouTube).")
      return
    end
    local split = channel:get_name()
    local request = c2.HTTPRequest.create(c2.HTTPMethod.Get, normalized.canonical)
    Innertube.default_headers(request)
    request:on_success(function(result)
      if result:status() ~= 200 then
        sys(channel, "No se pudo leer URL, status " .. tostring(result:status()))
        return
      end
      local parsed, parse_err = Html.parse_watch_page(result:data())
      if parse_err and parse_err ~= "continuation" then
        sys(channel, "No se pudo extraer metadata de YouTube: " .. parse_err)
        return
      end
      local key, key_err = Channels.add_binding(state, parsed and parsed.channelId, normalized.handle, split)
      if key_err then
        sys(channel, "No se pudo registrar el canal: " .. key_err)
        return
      end
      local _, ok = persist(state)
      if not ok then
        sys(channel, "No se pudo persistir estado.")
      end
      if parsed and parsed.continuation then
        ActiveStreams.add_stream(parsed.videoId, parsed.channelName, { split })
        Polling.read_chat(parsed)
        sys(channel, "Chat conectado al directo activo.")
      else
        sys(channel, "Canal registrado en modo offline; se monitorizará /live.")
      end
      Logging.info("channel_added", { split = split, channel = key })
    end)
    request:on_error(function(result)
      Logging.warning("url_read_error", { error = result:error() })
      sys(channel, "No se pudo abrir la URL de YouTube.")
    end)
    request:execute()
  end)
end

function Commands.run_offline_poll_once(state)
  local now = os.time()
  state._runtime = state._runtime or { offline_next_due = {} }
  local next_wakeup = 300
  for key, entry in pairs(state.channels or {}) do
    local splits = entry.splits or {}
    if #splits > 0 then
      local due_at = state._runtime.offline_next_due[key] or 0
      if now >= due_at then
        local attempts = ActiveStreams.bump_offline_attempt(key)
        local delay = require("src.support.backoff").offline_attempt_delay(attempts, {
          schedule = state.settings.offline_poll_schedule,
          max_seconds = state.settings.offline_poll_max
        })
        state._runtime.offline_next_due[key] = now + math.floor(delay)
        if delay < next_wakeup then
          next_wakeup = delay
        end
        local channel_url
        if entry.channel_id and entry.channel_id ~= "" then
          channel_url = "https://www.youtube.com/channel/" .. entry.channel_id .. "/live"
        elseif entry.handle and entry.handle ~= "" then
          channel_url = "https://www.youtube.com/@" .. entry.handle .. "/live"
        end
        if channel_url and Validation.is_safe_https_youtube(channel_url) then
          local req = c2.HTTPRequest.create(c2.HTTPMethod.Get, channel_url)
          Innertube.default_headers(req)
          req:on_success(function(result)
            local parsed, err = Html.parse_watch_page(result:data())
            if parsed and parsed.continuation and not ActiveStreams.by_video[parsed.videoId] then
              ActiveStreams.reset_offline_attempt(key)
              state._runtime.offline_next_due[key] = now + 30
              ActiveStreams.add_stream(parsed.videoId, parsed.channelName, splits)
              Polling.read_chat(parsed)
              Logging.info("stream_went_live", { channel = key, video = parsed.videoId })
            elseif err and err ~= "continuation" then
              Logging.rate_limited("warning", "offline:" .. key, 30000, 1, "offline_parse_issue", { channel = key, err = err })
            end
          end)
          req:on_error(function(result)
            Logging.rate_limited("warning", "offline-net:" .. key, 30000, 1, "offline_network_issue", {
              channel = key,
              error = result:error()
            })
          end)
          req:execute()
        end
      end
    end
  end
  local wake_ms = math.floor(math.max(30, next_wakeup) * 1000)
  c2.later(function() Commands.run_offline_poll_once(state) end, wake_ms)
end

return Commands
