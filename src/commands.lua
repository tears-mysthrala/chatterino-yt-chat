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

local Commands = {}
local MAX_SYNC_DELAY_MS = 30000

local function sys(ctx, msg)
  Adapter.system(ctx.channel:get_name(), msg)
end

local function channel_label(key, entry)
  return tostring(entry.display_name or entry.handle or entry.channel_id or key)
end

local function show_help(ctx)
  sys(ctx, "Comandos: <url> | list | status | pause <canal> | resume <canal> | remove <canal> | " ..
    "delay [ms] | config | export | import")
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
      sys(ctx, "No hay canales configurados.")
    end
    for _, key in ipairs(keys) do
      local entry = state.channels[key]
      sys(ctx, key .. " · " .. channel_label(key, entry) .. " · " ..
        (entry.paused and "pausado" or "activo") .. " · " .. tostring(#entry.splits) .. " split(s)")
    end
    return true
  end
  if command == "status" then
    local statuses = Polling.status()
    sys(ctx, tostring(#statuses) .. " stream(s) · delay " .. tostring(Polling.get_sync_delay()) .. " ms")
    for _, item in ipairs(statuses) do
      local next_ms = math.max(0, math.floor(((item.next_poll_ms or Clock.now_ms()) - Clock.now_ms()) / 1000))
      sys(ctx, tostring(item.channel_name or item.video_id) .. " · " .. tostring(item.splits) ..
        " split(s) · cola " .. tostring(item.queued_batches) .. " · próximo poll " .. tostring(next_ms) ..
        " s" .. (item.last_error and (" · error " .. item.last_error) or ""))
    end
    return true
  end
  if command == "config" then
    local caps = Capabilities.detect()
    sys(ctx, "delay=" .. tostring(Polling.get_sync_delay()) .. " ms" ..
      " · GUI=" .. (caps.settings_gui and "sí" or "no (API 2.5.5)") ..
      " · imágenes=" .. (caps.images and "disponibles" or "fallback textual"))
    return true
  end
  if command == "export" then
    local ok = Persistence.export_snapshot(state)
    sys(ctx, ok and "Configuración exportada a data/YT_CHAT.export.json." or "No se pudo exportar la configuración.")
    return true
  end
  if command == "import" then
    local imported, err = Persistence.import_snapshot()
    if not imported then
      sys(ctx, "No se pudo importar: " .. tostring(err) .. ".")
      return true
    end
    for _, item in ipairs(Polling.status()) do Polling.stop(item.video_id, "reconfigured") end
    replace_state(state, imported)
    Polling.set_sync_delay(state.settings.chat_sync_delay_ms)
    persist(state)
    sys(ctx, "Configuración importada y validada.")
    return true
  end
  if command == "pause" or command == "resume" or command == "remove" then
    local key = Channels.find(state, ctx.words[3])
    if not key then
      sys(ctx, "Canal no encontrado. Usa /yt-chat list.")
      return true
    end
    local entry = state.channels[key]
    if command == "remove" then
      if entry.channel_id then Polling.stop_by_channel(entry.channel_id, "removed") end
      Channels.remove(state, key)
      persist(state)
      sys(ctx, "Canal eliminado: " .. key .. ".")
    else
      local paused = command == "pause"
      Channels.set_paused(state, key, paused)
      if paused and entry.channel_id then Polling.stop_by_channel(entry.channel_id, "paused") end
      if not paused then Polling.check_channel_now(state, persist, key) end
      persist(state)
      sys(ctx, paused and ("Canal pausado: " .. key .. ".") or ("Canal reanudado: " .. key .. "."))
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
      show_help(ctx)
      return
    end
    if handle_control(state, persist, ctx, ctx.words[2]) then
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

  local caps = Capabilities.detect()
  if caps.completions then
    c2.register_callback(c2.EventType.CompletionRequested, function(event)
      if not event.full_text_content:match("^/yt%-chat") then
        return { hide_others = false, values = {} }
      end
      local values = { "help", "list", "status", "pause", "resume", "remove", "delay", "config",
        "export", "import" }
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
