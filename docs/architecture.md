# Arquitectura y contratos internos

Este documento es el contrato compartido entre módulos. Toda la lógica pura
(sin dependencia de `c2`) vive en `src/**` y es testeable fuera de Chatterino;
el acceso a la API de Chatterino se concentra en `src/c2_adapter.lua`,
`src/commands.lua`, `src/youtube/polling.lua` e `src/init.lua`.

## Flujo de datos

```text
HTTP get_live_chat
  -> youtube/continuations.lua   (token + intervalo)
  -> youtube/actions.lua         (action normalizada)
  -> youtube/renderers.lua       (renderer -> evento)
  -> support/delivery_queue.lua  (delay de presentación ordenado, si > 0)
  -> messages/*.lua              (construcción semántica del evento)
  -> messages/builder.lua        (evento -> spec de mensaje Chatterino)
  -> c2_adapter.lua              (spec -> c2.Message + entrega a splits)
```

El delay de sincronización no modifica el intervalo de polling indicado por
YouTube. Cada respuesta se normaliza inmediatamente y sus eventos se encolan
por `video_id` con orden estable. La cola mantiene un único timer activo por
stream, aísla fallos de callbacks y se cancela cuando el stream se detiene sin
drain. Al finalizar naturalmente, el marcador de fin se encola detrás de los
eventos pendientes para no perder el último lote.
En Chatterino 2.5.5 el reloj monotónico tiene resolución de 100 ms; el timer
solicita el delay configurado y la entrega queda sujeta a esa granularidad.

La cola limita cada stream a 128 lotes. Si un upstream anómalo alcanza ese
límite, aplica backpressure entregando el lote más antiguo y registra el hecho
en métricas locales; nunca crece sin límite ni pierde silenciosamente eventos.

`support/health.lua` conserva solo contadores y gauges en memoria. El comando
de exportación escribe un snapshot sin contenido, tokens ni payloads. La capa
de adaptador materializa elementos declarativos `remote-image` únicamente si
la API verificada `c2.Image` existe y la URL supera la allowlist.

## Evento normalizado (IR)

Tabla Lua. Campos obligatorios: `kind`. Todo lo demás es opcional y defensivo.

```lua
{
  kind = "text_message" | "super_chat" | "super_sticker" | "membership"
       | "membership_gift" | "membership_gift_received" | "deleted_message"
       | "author_deleted" | "replaced_message" | "pinned" | "pin_removed"
       | "poll" | "poll_update" | "poll_closed" | "ticker_paid"
       | "ticker_member" | "mode_change" | "system" | "placeholder"
       | "unknown_event",

  id = "string YouTube",              -- id del mensaje si existe
  timestamp_usec = 1234567890000000,  -- número o string numérica
  author = "nombre visible",
  author_channel_id = "UC...",
  roles = { owner=false, moderator=false, member=false, verified=false },
  badges = { { kind="moderator"|"member"|"verified"|"owner"|"custom",
               label="tooltip", months=12 } },

  runs = {                            -- fragmentos del texto en orden
    { type="text",  text="hola" },
    { type="link",  text="example.com", url="https://..." },
    { type="emoji", emoji="😀" },     -- unicode, se muestra tal cual
    { type="emote", name=":wave:", url="https://yt3.../wave.png", custom=true },
  },
  text = "texto plano aplanado (para message_text/search)",

  amount = "5,00 €",                  -- cadena verbatim de YouTube, sin conversión
  amount_color = 4294953512,          -- entero ARGB si existe
  header_text = "...",                -- membresías/sistema
  sub_text  = "...",
  level = "nombre de nivel de membresía",
  gift_count = 5,
  sticker = { alt="Thanks!", url="https://..." },

  target_message_id = "id afectado",  -- mutaciones
  target_author_channel_id = "UC...",
  replacement = { --[[ evento anidado ]] },

  poll = { question="...", options={ {text=, votes=, ratio=} }, total_votes=,
           status="open"|"closed" },
  ticker = { kind="paid"|"member", duration_sec=30, detail_text="..." },
  mode = { slow_seconds=10, members_only=true, subscribers_only=false },

  system_text = "texto de sistema legible",
  banner = { header="...", text="..." },
  source_action = "addChatItemAction",
  source_renderer = "liveChatTextMessageRenderer", -- solo para unknown_event
}
```

Reglas:

- Ningún productor lanza error por campos ausentes o de tipo incorrecto;
  extrae lo reconocible y deja el resto a `nil`.
- `builder.lua` nunca recibe un `nil`; eventos sin contenido útil se
  convierten en `unknown_event` o se descartan solo si GOAL.md lo permite
  (p. ej. placeholder sustituido por su resultado final).
- Todo texto de usuario se trunca a límites de `support/validation.lua`
  antes de construir el mensaje.

## Spec de mensaje Chatterino (salida de builder)

```lua
{
  id = "yt-chat-" .. event.id,
  message_text = "...",          -- texto plano completo
  elements = {                   -- elementos c2 compatibles (solo texto/timestamp)
    { type="text", text="▶️", color="red", style="ChatMediumBold" },
    { type="text", text="YT", color="system", style="ChatMediumBold" },
    { type="timestamp", time=1234 },
    ...
  },
  system = false,                -- true -> add_system_message(texto)
}
```

Chatterino 2.5.5 solo construye elementos de texto, mención, timestamp y salto
de línea: emotes, stickers, avatares e insignias se representan textualmente
(degradación documentada en COMPATIBILITY.md). La imagen remota nativa queda
condicionada a detectar la API verificada `c2.Image` en una versión futura.
Las mutaciones usan `find_message_by_id` y `replace_message` cuando existe el
mensaje original; en caso contrario producen un evento informativo inequívoco.

## Módulos y responsabilidades

| Módulo | Responsabilidad |
| --- | --- |
| `support/validation.lua` | allowlist de hosts, límites de tamaño, clamps, sanitización |
| `support/logging.lua` | niveles, redacción, rate-limit y deduplicación de logs |
| `support/rate_limit.lua` | buckets con expiración y tamaño limitado |
| `support/backoff.lua` | backoff offline (30/60/120/300+jitter) y de chat (<=30 s, Retry-After) |
| `state/persistence.lua` | esquema, escritura atómica tmp+rename, .bak, debounce, IO_LOCK |
| `state/migrations.lua` | migraciones versionadas del esquema |
| `state/channels.lua` | canales persistidos, dedupe por channel_id/handle, splits |
| `state/active_streams.lua` | estado efímero: streams activos, dedupe IDs (TTL+tamaño), offline backoff |
| `youtube/url.lua` | normalización de URLs aceptadas, extracción videoId/handle/channelId |
| `youtube/html.lua` | extracción defensiva de metadatos del HTML (apiKey, clientVersion, continuation...) |
| `youtube/innertube.lua` | construcción de requests get_live_chat, headers, payload |
| `youtube/continuations.lua` | parseo/validación de continuations y timeoutMs |
| `youtube/actions.lua` | dispatch de acciones -> eventos |
| `youtube/renderers.lua` | dispatch de renderers -> eventos |
| `youtube/polling.lua` | bucles de polling chat/offline, reconexión, errores HTTP |
| `messages/*.lua` | construcción semántica por categoría |
| `messages/builder.lua` | evento -> spec Chatterino |
| `messages/fallback.lua` | evento desconocido seguro |
| `c2_adapter.lua` | único punto que toca `c2` para mensajes/canales |
| `commands.lua` | `/yt-chat` |
| `init.lua` | bootstrap |

## Estado persistido (único archivo `YT_CHAT.json`)

```json
{
  "schema_version": 5,
  "settings": { "debug": false, "offline_poll": {"start":30,"max":300} },
  "channels": {
    "<key>": { "channel_id": "UC...", "handle": "nombre",
               "display_name": "...", "splits": ["split1"] }
  }
}
```

Nunca se persisten: apiKey, continuations, payloads, cookies, mensajes,
historial. La clave de canal prioriza `channel_id` estable sobre handle.

## Límites defensivos (validation.lua)

- Respuesta HTTP: 4 MiB máx. HTML watch page: 8 MiB máx.
- Texto de mensaje: 4000 chars. Nombre autor: 200. Runs: máx 200 por mensaje.
- IDs: 128 chars alfanuméricos/guiones. Continuation token: no se loguea.
- dedupe de IDs: máx 5000/stream, TTL 30 min. Buckets de rate limit: máx 256.
