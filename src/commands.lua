local Logging = require("src.support.logging")
local Url = require("src.youtube.url")
local Html = require("src.youtube.html")
local Polling = require("src.youtube.polling")
local Channels = require("src.state.channels")
local ActiveStreams = require("src.state.active_streams")
local Adapter = require("src.c2_adapter")

local Commands = {}
local MAX_SYNC_DELAY_MS = 30000

local function sys(ctx, msg)
  Adapter.system(ctx.channel:get_name(), msg)
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
      sys(ctx, "No se pudo leer la URL (HTTP " .. tostring(result:status()) .. ").")
      return
    end
    local parsed, err = Html.parse_watch_page(result:data())
    if not parsed then
      if err == "continuation" then
        sys(ctx, "La página parece un directo pero no se encontró el chat; reintenta en unos segundos.")
      else
        sys(ctx, "No se pudo extraer metadata de YouTube (" .. tostring(err) .. ").")
      end
      return
    end
    local key, key_err = Channels.add_binding(state, parsed.channelId, normalized.handle, split)
    if key_err then
      sys(ctx, "No se pudo registrar el canal: " .. key_err)
      return
    end
    if parsed.channelName then
      Channels.set_display_name(state, key, parsed.channelName)
    end
    persist(state)
    if parsed.continuation then
      if start_chat(state, parsed, split) then
        sys(ctx, "Chat conectado al directo activo.")
      else
        sys(ctx, "Este directo ya está siendo seguido.")
      end
    else
      sys(ctx, "Canal registrado en modo offline; se conectará cuando empiece un directo.")
    end
    Logging.info("channel_added", { split = split, channel = key })
  end)
  request:on_error(function()
    Logging.warning("url_read_error", { host = "www.youtube.com" })
    sys(ctx, "Error de red al abrir la URL de YouTube.")
  end)
  request:execute()
end

function Commands.register(state, persist)
  local c2 = rawget(_G, "c2")
  c2.register_command("/yt-chat", function(ctx)
    if #ctx.words < 2 then
      sys(ctx, "Uso: /yt-chat <url de YouTube> | /yt-chat delay [0-30000 ms]")
      return
    end
    if ctx.words[2] == "delay" then
      if #ctx.words < 3 then
        sys(ctx, "Delay de sincronización: " .. tostring(Polling.get_sync_delay()) .. " ms.")
        return
      end
      local raw = ctx.words[3]
      local delay = type(raw) == "string" and raw:match("^%d+$") and tonumber(raw) or nil
      if not delay or delay > MAX_SYNC_DELAY_MS then
        sys(ctx, "Delay no válido. Usa un entero entre 0 y 30000 ms.")
        return
      end
      state.settings.chat_sync_delay_ms = Polling.set_sync_delay(delay)
      persist(state)
      sys(ctx, "Delay de sincronización ajustado a " .. tostring(delay) .. " ms.")
      return
    end
    local normalized, err = Url.normalize(ctx.words[2])
    if not normalized then
      sys(ctx, "URL no válida o no soportada (" .. tostring(err) ..
        "). Solo HTTPS en hosts oficiales de YouTube.")
      return
    end
    handle_url(state, persist, ctx, normalized)
  end)
end

return Commands
