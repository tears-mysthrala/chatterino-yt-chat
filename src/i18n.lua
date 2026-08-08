local I18n = {}
local language = "es"

local TEXT = {
  es = {
    help = "Comandos: <url> | lista | estado | salud | pausar <canal> | reanudar <canal> | " ..
        "eliminar <canal> | auto <@usuario> | retardo [ms] | idioma [es|en] | configurar | " ..
        "exportar | importar",
    no_channels = "No hay canales configurados.", channel_missing = "Canal no encontrado. Usa /yt-chat lista.",
    exported = "Configuración exportada a data/YT_CHAT.export.json.", export_failed = "No se pudo exportar la configuración.",
    imported = "Configuración importada y validada.", import_failed = "No se pudo importar: {error}.",
    paused = "Canal pausado: {channel}.", resumed = "Canal reanudado: {channel}.", removed = "Canal eliminado: {channel}.",
    language = "Idioma: {language}.", invalid_language = "Idioma no válido. Usa es o en.",
    usage_channel = "Uso: /yt-chat {command} <canal>", paused_url = "El canal está pausado. Usa /yt-chat reanudar {channel}.",
    usage_auto = "Uso: /yt-chat auto @usuario",
    gui_unavailable = "no (API 2.5.5)", images_label = "imágenes",
    gui_not_supported = "Chatterino 2.5.5 no permite que los plugins añadan controles a Ajustes. " ..
        "No se puede activar una GUI desde este plugin.",
    diagnostic_exported = "Diagnóstico exportado a data/YT_CHAT.diagnostics.json.",
    diagnostic_failed = "No se pudo exportar el diagnóstico.",
    status_summary = "{streams} directo(s) · retardo {delay} ms",
    status_item = "{channel} · {splits} panel(es) · cola {queued} · próximo sondeo {next} s{error}",
    status_error = " · error {error}",
    config_summary = "idioma={language} · retardo={delay} ms · GUI={gui} · imágenes={images}",
    health_summary = "salud · actividad {uptime} s · solicitudes {requests} · reintentos {retries} · " ..
        "lotes {batches} · incompatibles {unknown}",
    state_active = "activo", state_paused = "pausado", queue = "cola", next_poll = "próximo poll",
    image_available = "disponibles", image_fallback = "fallback textual", yes = "sí",
    delay_current = "Delay de sincronización: {delay} ms.", delay_invalid = "Delay no válido. Usa un entero entre 0 y 30000 ms.",
    delay_set = "Delay de sincronización ajustado a {delay} ms.",
    http_read = "No se pudo leer la URL (HTTP {status}).",
    no_chat = "La página parece un directo pero no se encontró el chat; reintenta en unos segundos.",
    metadata = "No se pudo extraer metadata de YouTube ({error}).", register = "No se pudo registrar el canal: {error}",
    connected = "Chat conectado al directo activo.", already = "Este directo ya está siendo seguido.",
    offline = "Canal registrado en modo offline; se conectará cuando empiece un directo.",
    network = "Error de red al abrir la URL de YouTube.",
    invalid_url = "URL no válida o no soportada ({error}). Solo HTTPS en hosts oficiales de YouTube.",
    stopped_paused = "Vigilancia del canal pausada.", stopped_removed = "Canal eliminado de la vigilancia.",
    stopped_import = "Chat detenido para aplicar la configuración importada.",
    stopped = "Directo finalizado o chat cerrado ({reason}). El canal vuelve a vigilancia offline.",
    live = "Directo detectado: chat conectado."
  },
  en = {
    help = "Commands: <url> | list | status | health | pause <channel> | resume <channel> | " ..
        "remove <channel> | auto <@handle> | delay [ms] | language [es|en] | config | export | import",
    no_channels = "No channels configured.", channel_missing = "Channel not found. Use /yt-chat list.",
    exported = "Configuration exported to data/YT_CHAT.export.json.", export_failed = "Could not export configuration.",
    imported = "Configuration imported and validated.", import_failed = "Could not import: {error}.",
    paused = "Channel paused: {channel}.", resumed = "Channel resumed: {channel}.", removed = "Channel removed: {channel}.",
    language = "Language: {language}.", invalid_language = "Invalid language. Use es or en.",
    usage_channel = "Usage: /yt-chat {command} <channel>", paused_url = "The channel is paused. Use /yt-chat resume {channel}.",
    usage_auto = "Usage: /yt-chat auto @handle",
    gui_unavailable = "no (API 2.5.5)", images_label = "images",
    gui_not_supported = "Chatterino 2.5.5 does not let plugins add controls to Settings. " ..
        "This plugin cannot enable a GUI.",
    diagnostic_exported = "Diagnostics exported to data/YT_CHAT.diagnostics.json.",
    diagnostic_failed = "Could not export diagnostics.",
    status_summary = "{streams} stream(s) · delay {delay} ms",
    status_item = "{channel} · {splits} split(s) · queue {queued} · next poll {next} s{error}",
    status_error = " · error {error}",
    config_summary = "language={language} · delay={delay} ms · GUI={gui} · images={images}",
    health_summary = "health · uptime {uptime} s · requests {requests} · retries {retries} · " ..
        "batches {batches} · incompatible {unknown}",
    state_active = "active", state_paused = "paused", queue = "queue", next_poll = "next poll",
    image_available = "available", image_fallback = "text fallback", yes = "yes",
    delay_current = "Synchronization delay: {delay} ms.", delay_invalid = "Invalid delay. Use an integer from 0 to 30000 ms.",
    delay_set = "Synchronization delay set to {delay} ms.",
    http_read = "Could not read the URL (HTTP {status}).",
    no_chat = "The page looks live but chat was not found; try again in a few seconds.",
    metadata = "Could not extract YouTube metadata ({error}).", register = "Could not register channel: {error}",
    connected = "Connected to the active live chat.", already = "This live stream is already being monitored.",
    offline = "Channel registered offline; it will connect when a live stream starts.",
    network = "Network error while opening the YouTube URL.",
    invalid_url = "Invalid or unsupported URL ({error}). Only HTTPS on official YouTube hosts is allowed.",
    stopped_paused = "Channel monitoring paused.", stopped_removed = "Channel removed from monitoring.",
    stopped_import = "Chat stopped to apply imported configuration.",
    stopped = "Stream ended or chat closed ({reason}). The channel is back in offline monitoring.",
    live = "Live stream detected: chat connected."
  }
}

function I18n.set(value)
  if TEXT[value] then language = value return true end
  return false
end

function I18n.get() return language end

function I18n.t(key, vars)
  local value = (TEXT[language] and TEXT[language][key]) or TEXT.es[key] or key
  for name, replacement in pairs(vars or {}) do
    value = value:gsub("{" .. name .. "}", function() return tostring(replacement) end)
  end
  return value
end

return I18n
