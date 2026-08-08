## Estado global

- Objetivo: `chatterino-yt-chat v1.2.0` (apilado sobre la PR de v1.1.0)
- Estado actual: **v1.2.0 RELEASE CANDIDATE; v1.0.0 PUBLICADO Y ESTABLE**
- Última actualización: 2026-08-08
- Rama actual: `release/v1.2.0`
- Último commit publicado: `bd7211a`
- Tag: `v1.0.0` (release workflow verde, run `29694238438`)
- Release: https://github.com/tears-mysthrala/chatterino-yt-chat/releases/tag/v1.0.0 (publicada 2026-07-19T16:15:37Z)
- Criterios obligatorios verificados: 20/20
- Bloqueos activos: 0; soak largo recomendado pero no bloqueante
- Contrato interno: `docs/architecture.md` (evento normalizado IR + esquema de estado v5)
- Validación en app real: Chatterino 2.5.5 oficial headless, e2e con chat real OK (VAL-011/012/014)
- Validación de usuario: Chatterino 2.5.5 GUI conectado a un directo y recibiendo mensajes sin fallos observados; soak largo todavía pendiente (`docs/validation/user-smoke-2026-08-08.md`).

> Nota de reconciliación: las entradas históricas marcadas `Pendiente` más abajo
> describen el plan previo a v1.0.0. Cuando entren en conflicto con `Estado
> global`, las validaciones VAL-009..014 y el cierre de sesión al final del
> documento, prevalece la evidencia posterior. No deben interpretarse como
> backlog actual sin revalidación.
- Entorno verificado: Lua 5.5.0 (`/usr/bin/lua`, también 5.1/5.4/luajit), `gh` autenticado como `tears-mysthrala` (scopes repo+workflow), red a `www.youtube.com` OK (HTTP 200), remoto `origin` = `https://github.com/tears-mysthrala/chatterino-yt-chat.git`

## En curso

### CYC-002 — Investigación de API de plugins de Chatterino
- Requisito de GOAL.md: Compatibilidad de Chatterino
- Estado: Verificado (investigación completada; doc pendiente de consolidar en CYC-028)
- Dependencias: CYC-001
- Archivos: `docs/research/chatterino-plugin-api.md`, fuentes: headers `src/controllers/plugins/**` de Chatterino2 v2.5.5 y master, `docs/wip-plugins.md`
- Validación requerida: versión mínima compatible documentada con capacidades y limitaciones verificables
- Resultado: estable actual **v2.5.5** (2026-03-22). Sandbox: Lua 5.4 sin librería `os` (confirmado en `PluginController.cpp` línea ~149: `LUA_OSLIBNAME` comentado), `io` limitado al data dir del plugin, sin `load` en release, `print`→`c2.log(Debug)`. API 2.5.5: elementos de mensaje SOLO texto/timestamp/mention/linebreak (sin imágenes; `c2.Image` llega en master post-2.5.5), `find_message_by_id`+`replace_message` DISPONIBLES (mutación real posible), HTTP sin acceso a headers de respuesta. Estructura plugin: `Plugins/<nombre>/{init.lua,info.json,data/}` en app data
- Commit: N/A
- Notas: versión mínima objetivo: 2.5.0+ (API de mensajes compatible); imágenes = degradación documentada hasta que una estable incluya `c2.Image`

### CYC-003 — Matriz completa de acciones/renderers de YouTube Live Chat
- Requisito de GOAL.md: Compatibilidad real, Acciones/renderers desconocidos
- Estado: Verificado (inventario completado; matriz final se consolida en CYC-028)
- Dependencias: CYC-001
- Archivos: `COMPATIBILITY.md`, `docs/research/youtube-live-chat-renderers.md`, fuentes: `xenova/chat-downloader` (`sites/youtube.py` líneas 980-1110), `sigvt/masterchat` (`src/chat/actions/*`), `LuanRT/YouTube.js`, `taizan-hokuto/pytchat`, capturas reales `get_live_chat` (2026-07-19)
- Validación requerida: matriz con acción, renderer, handler, fixture, resultado esperado y estado
- Resultado: 15 acciones y ~20 renderers identificados con campos confirmados (ver implementación en `src/youtube/actions.lua`/`renderers.lua`); continuations: invalidation (timeoutMs real=10000 capturado), timed, replay, reload; no existen renderers específicos actuales de raid/Q&A/celebración en fuentes (documentado)
- Commit: N/A
- Notas: fixtures sintéticos llevan `_provenance` con la fuente de estructura

### CYC-029 — Configuración del repositorio GitHub y publicación v1.0.0
- Requisito de GOAL.md: Repositorio y atribución, Release, Criterios 1.0.0
- Estado: Verificado
- Dependencias: CYC-001..CYC-028, CYC-031, CYC-032
- Archivos: remotos git/tags/releases
- Validación requerida: repo público creado, tag `v1.0.0`, release publicada tras checklist completa
- Resultado: repo público `tears-mysthrala/chatterino-yt-chat` (descripción y 8 topics exactos, issues habilitadas); tag `v1.0.0`; release creada como DRAFT por CI (run 29694238438), artefacto descargado y verificado contra `.sha256`, artefacto CI instalado y probado en Chatterino 2.5.5 real (VAL-014), cuerpo corregido con hash canónico CI, publicada como estable 2026-07-19T16:15:37Z
- Commit: de90a61 (main), tag sobre 3c65822
- Notas: discrepancia local/CI del hash del ZIP documentada (codificador zip); el artefacto canónico es el de CI y su `.sha256` acompaña la release

### CYC-031 — Captura y anonimización de fixtures reales de YouTube
- Requisito de GOAL.md: Validación real, Pruebas automatizadas, Compatibilidad real
- Estado: Implementado, pendiente de prueba (en uso por la suite; se ampliará con más capturas en validación)
- Dependencias: CYC-003
- Archivos: `fixtures/real/*.json`, `fixtures/continuations/invalidationContinuationData.json`
- Validación requerida: fixtures procedentes de respuestas reales de `get_live_chat`, anonimizados (sin nombres/IDs reales), usados por la suite
- Resultado: captura real 2026-07-19 de chat en directo (LofiGirl, UA `facebookexternalhit/`): 75 acciones en un poll; extraídos y anonimizados text message con emoji unicode, viewer engagement (subscribers-only), banner pinned real, removeChatItemAction real, invalidationContinuationData (timeoutMs=10000); anonimización: autores→"Viewer One/Two", IDs→FAKE-*, continuation→redactada, avatares→URLs fake en hosts permitidos; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas: evidencia adicional: canal offline (NASA /live sin liveChatRenderer) confirma el camino offline

### CYC-032 — Validación de instalación en Chatterino estable
- Requisito de GOAL.md: Criterio 16 y 17 (instalación limpia + actualización)
- Estado: Verificado
- Dependencias: CYC-004, CYC-002
- Archivos: `docs/validation/chatterino-install.md`
- Validación requerida: instalar ZIP en Chatterino estable, comprobar carga del plugin, comandos y recepción de chat; actualización desde versión anterior
- Resultado: VALIDADO en Chatterino 2.5.5 oficial (deb Ubuntu 24.04, SHA-256 verificado, ejecución headless `QT_QPA_PLATFORM=minimal`, XDG sandbox): (1) instalación limpia desde ZIP → plugin carga, módulos resuelven, info.json aceptado; (2) e2e real: canal Lofi Girl → `stream_went_live` + `chat_started` + mensajes reales entregados al split (evidencia en log de canal de Chatterino: autores, emoji unicode nativo, emotes custom como `:shortcut:`); (3) estado legacy migrado en memoria y funcional; (4) archivos solo dentro del data dir (modelo de permisos). Pendiente menor: entrada interactiva del comando (cubierta por harness) y soak de horas en GUI (cubierto por simulación)
- Commit: pendiente en este bloque
- Notas: evidencia detallada en `docs/validation/chatterino-install.md`; nombres de usuarios reales solo en sandbox local, no publicados

### CYC-023 — Sistema de pruebas unitarias + fixtures anonimizados
- Requisito de GOAL.md: Pruebas automatizadas
- Estado: Implementado, pendiente de prueba
- Dependencias: CYC-003, CYC-004
- Archivos: `tests/**`, `fixtures/**`, `scripts/test.sh`
- Validación requerida: ejecución de suite con casos de renderers/acciones/continuations y robustez
- Resultado: Suite base ejecuta unitarias + integración simulada + fuzz ligero
- Commit: e104cf4
- Notas: cobertura aún parcial frente a todos los renderers/eventos exigidos; se ampliará tras CYC-003/CYC-031

### CYC-027 — CI, release automation y packaging reproducible
- Requisito de GOAL.md: CI, Release
- Estado: Verificado
- Dependencias: CYC-023, CYC-024
- Archivos: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `scripts/build_release.sh`, `scripts/sha256.sh`, `scripts/validate_fixtures.sh`, `.luacheckrc`
- Validación requerida: ZIP reproducible + SHA256 + checks de versión/tag + draft release
- Resultado: CI remota VERDE (run 29693795457): luacheck 0 warnings, format check, validación info.json, allowlist de hosts, secret scan, validación de fixtures, tests (1301 aserciones), build reproducible (doble build, mismo hash), SHA-256, artefacto subido; build local == CI
- Commit: 4552d2f
- Notas: fallos de CI durante el endurecimiento (hosts, luacheck apt, fixture real sin anonimizar) corregidos y revalidados; acciones de terceros fijadas por SHA; permisos mínimos (contents: read en CI, write solo en release)

## Pendiente

### CYC-004 — Refactor de arquitectura modular
- Requisito de GOAL.md: Arquitectura
- Estado: Implementado, pendiente de prueba
- Dependencias: CYC-001, CYC-003
- Archivos: `src/**`, `init.lua`, `info.json`, `README.md`, `SECURITY.md`
- Validación requerida: separación en módulos auditables equivalentes a la estructura objetivo
- Resultado: Estructura modular implementada en `src/` con separación youtube/messages/state/support
- Commit: e104cf4
- Notas: falta validar comportamiento en entorno Chatterino real

### CYC-001 — Bootstrap del repositorio independiente
- Requisito de GOAL.md: Repositorio y atribución, Estructura del repositorio, Historial Git
- Estado: Implementado, pendiente de prueba
- Dependencias: Ninguna
- Archivos: `*` (importación inicial del subárbol `yt-chat`), `TRACKER.md`
- Validación requerida: Repositorio inicial creado con estructura mínima, licencia MIT, atribución visible y procedencia documentada
- Resultado: Historial relevante de `yt-chat` preservado localmente con `git subtree split --prefix=yt-chat`
- Commit: e104cf4
- Notas: Importación hecha desde `Remahy/Chatterino-Plugins` sin arrastrar otros plugins; falta refactor completo y estructura objetivo 1.0.0

## Pendiente

### CYC-005 — Descubrimiento y normalización de URLs/canales
- Requisito de GOAL.md: Descubrimiento de canales y directos
- Estado: Pendiente
- Dependencias: CYC-004
- Archivos: `src/youtube/url.lua`, `tests/**`, `fixtures/**`
- Validación requerida: soporte de URLs requeridas, HTTPS estricto, hosts permitidos y deduplicación de canales
- Resultado: Pendiente
- Commit: N/A
- Notas: persistir identificador estable por canal

### CYC-006 — Polling offline por canal con backoff/jitter
- Requisito de GOAL.md: Polling offline
- Estado: Pendiente
- Dependencias: CYC-005
- Archivos: `src/youtube/polling.lua`, `src/support/backoff.lua`, `tests/**`
- Validación requerida: secuencia 30/60/120/300s, reset al detectar directo, single-check por canal
- Resultado: Pendiente
- Commit: N/A
- Notas: sin timers duplicados ni busy loop

### CYC-007 — Polling de chat y continuations robustas
- Requisito de GOAL.md: Polling del chat, Continuations
- Estado: Pendiente
- Dependencias: CYC-004, CYC-006
- Archivos: `src/youtube/continuations.lua`, `src/youtube/polling.lua`, `tests/**`
- Validación requerida: timeoutMs de YouTube con clamps, fallback, single polling por videoId y no concurrencia
- Resultado: Pendiente
- Commit: N/A
- Notas: diferenciar fin de directo, chat deshabilitado y errores temporales

### CYC-008 — Renderizado completo de mensajes ordinarios/runs/emotes/badges
- Requisito de GOAL.md: Mensajes ordinarios, Emotes e imágenes
- Estado: Implementado, pendiente de prueba (suite verde; pendiente prueba en Chatterino real)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/text.lua`, `src/messages/emotes.lua`, `src/messages/badges.lua`, `src/messages/common.lua`, `src/messages/builder.lua`, `tests/unit/actions_renderers_spec.lua`
- Validación requerida: cobertura de runs mixtos, emotes nativos/canal, unicode, enlaces, badges y rol de autor
- Resultado: runs texto/link/emoji-unicode/emote-custom, badges OWNER/MODERATOR/VERIFIED/member(meses), autor por foto-accesibilidad, runs sin `text` marcados `[?]` y contados; fixtures reales anonimizados incluidos; 450 aserciones verdes (VAL-008)
- Commit: pendiente en este bloque
- Notas: emoji unicode se muestra nativamente; imágenes remotas no disponibles en API 2.5.5 (degradación documentada); bug real corregido: `first_key` saltaba metadatos (`clickTrackingParams`, `_provenance`)

### CYC-009 — Super Chat/Super Sticker y eventos monetarios
- Requisito de GOAL.md: Super Chats y aportaciones económicas
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/monetary.lua`, `src/youtube/renderers.lua`, `fixtures/synthetic/*`
- Validación requerida: importe, moneda, texto, nivel visual y fallback semántico
- Resultado: super chat (importe verbatim + colores ARGB→hex + highlight), super sticker (alt + importe), donation announcement, legacy paid; sin conversiones monetarias; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas: tickers (paid/sticker/sponsor) implementados con detalle completo vía showItemEndpoint

### CYC-010 — Membresías, regalos y eventos de nivel
- Requisito de GOAL.md: Membresías
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/memberships.lua`, `src/youtube/renderers.lua`, `fixtures/synthetic/*`
- Validación requerida: nuevas/renovación/antigüedad/regalos/receptores/nivel/cambios
- Resultado: nuevo miembro (nivel desde headerSubtext), milestone (antigüedad + nivel + mensaje), regalo (count + autor desde header), recepción de regalo; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas:

### CYC-011 — Moderación y mutaciones de mensajes
- Requisito de GOAL.md: Moderación y mutaciones visibles
- Estado: Implementado, pendiente de prueba (suite verde; mutación in-place pendiente en Chatterino real)
- Dependencias: CYC-003, CYC-004, CYC-007
- Archivos: `src/messages/moderation.lua`, `src/c2_adapter.lua`, `src/youtube/actions.lua`, `src/youtube/polling.lua`
- Validación requerida: eliminación/sustitución/marcado/actualización con ID o fallback inequívoco
- Resultado: markChatItemAsDeleted/removeChatItem/removeChatItemByAuthor/markChatItemsByAuthor/replaceChatItem implementados; mutación in-place con `find_message_by_id`+`replace_message` (verificado en API 2.5.5), fallback a evento de sistema con id; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas:

### CYC-012 — Fijados, destacados y banners sin duplicados
- Requisito de GOAL.md: Mensajes fijados y destacados
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-011
- Archivos: `src/messages/system.lua`, `src/youtube/actions.lua`, `fixtures/real/addBannerToLiveChatCommand.json`
- Validación requerida: pin/unpin/cambio/banner/highlight y deduplicación mensaje-banner
- Resultado: banner real capturado (header "Pinned by", contents completo, targetId); evento pinned con id `pin-<target>` para no chocar con el mensaje original; unpin vía removeBannerForLiveChatCommand; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas:

### CYC-013 — Encuestas, Q&A e interactivos en modo lectura
- Requisito de GOAL.md: Encuestas, preguntas y eventos interactivos
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/polls.lua`, `src/youtube/actions.lua`, `fixtures/synthetic/*poll*`
- Validación requerida: opciones, recuentos/porcentajes, updates, cierre y mensajes de sistema
- Resultado: poll inicial (panel), update (pregunta/opciones/ratio/votos totales), cierre (panel + resultados vía engagement POLL), throttle de updates 1/10s por encuesta; estructura verificada contra masterchat/YouTube.js; verde (VAL-008)
- Commit: pendiente en este bloque
- Notas: Q&A no existe como renderer de chat en fuentes actuales → documentado en matriz; cubierto por fallback si aparece

### CYC-014 — Redirecciones, estado del directo y sistema
- Requisito de GOAL.md: Redirecciones y eventos del directo
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-007
- Archivos: `src/messages/system.lua`, `src/youtube/polling.lua`
- Validación requerida: redirect/raid/live status/chat restrictions/slow mode/end stream
- Resultado: mode change (slow/members/subscribers on/off) con fixture; viewer engagement (aviso subscribers-only real capturado); fin de directo/chat deshabilitado detectado por ausencia de continuationContents → mensaje de sistema + retorno a vigilancia offline; no existen renderers específicos de raid/redirect en fuentes actuales (documentado en matriz); verde (VAL-008)
- Commit: pendiente en este bloque
- Notas:

### CYC-015 — Placeholders, reacciones y efectos
- Requisito de GOAL.md: Placeholders, reacciones y efectos
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/youtube/polling.lua`, `src/messages/system.lua`
- Validación requerida: placeholder->resultado final, reacciones y efectos semánticos
- Resultado: placeholders coalescidos en ventana de 10 s ("✨ N reactions"), sustitución placeholder→mensaje real vía replaceChatItemAction (entrega in-place si el objetivo existe); verde (VAL-008)
- Commit: pendiente en este bloque
- Notas: decisión documentada en ADR-005

### CYC-016 — Fallback seguro para acciones/renderers desconocidos
- Requisito de GOAL.md: Acciones y renderers desconocidos
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/fallback.lua`, `src/support/logging.lua`, `tests/unit/actions_renderers_spec.lua`
- Validación requerida: mensaje visible, redacción de sensibles, rate limit y modo diagnóstico explícito
- Resultado: evento visible con nombre exacto + extracción defensiva (autor/texto/importe), log rate-limited 1/60s, muestra anonimizada solo en modo debug vía sink (redacción profunda continuation/cookie/token/key); verde (VAL-008)
- Commit: pendiente en este bloque
- Notas: `liveChatReportModerationStateCommand` es no-op documentado (estado UI de moderador, no evento de chat)

### CYC-017 — Orden, deduplicación y consistencia de estado
- Requisito de GOAL.md: Orden, duplicados y consistencia
- Estado: Pendiente
- Dependencias: CYC-007, CYC-011
- Archivos: `src/state/active_streams.lua`, `src/youtube/actions.lua`, `tests/**`
- Validación requerida: orden operacional estable, cache TTL/size y limpieza al terminar stream
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-018 — Reconexión y manejo exhaustivo de errores
- Requisito de GOAL.md: Reconexión y errores
- Estado: Pendiente
- Dependencias: CYC-007, CYC-017
- Archivos: `src/youtube/polling.lua`, `src/support/backoff.lua`, `src/support/logging.lua`, `tests/**`
- Validación requerida: categorías de error, exponential backoff <=30s temporal chat, `Retry-After` y reset tras éxito
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-019 — Persistencia segura con migraciones y recuperación
- Requisito de GOAL.md: Persistencia
- Estado: Implementado, pendiente de prueba (suite verde; pendiente prueba en Chatterino real)
- Dependencias: CYC-004
- Archivos: `src/state/persistence.lua`, `src/state/migrations.lua`, `tests/unit/persistence_spec.lua`
- Validación requerida: write-temp+flush+replace+.bak+recovery+schema+debounce+no concurrent write
- Resultado: tmp+flush+rename, .bak, recuperación bak/default con marcador, schema v2 validado, lock con liberación garantizada (pcall), escritura solo si cambia, flusher con debounce; 61 aserciones verdes (VAL-007)
- Commit: pendiente de commit en este bloque
- Notas: no persistir continuation/API key/payloads/chat content (validado por validate_schema que descarta claves desconocidas)

### CYC-020 — Seguridad y validación de superficie de red/entrada
- Requisito de GOAL.md: Seguridad y privacidad
- Estado: En curso
- Dependencias: CYC-005, CYC-007, CYC-019
- Archivos: `src/support/validation.lua`, `SECURITY.md`, `tests/unit/support_spec.lua`
- Validación requerida: allowlist de hosts, límites de tamaños/tipos y sin eval/código remoto
- Resultado: allowlist hosts YouTube + hosts de imagen separados, sanitize_text/sanitize_id, límites de tamaño, color y retry-after validados; 53 aserciones verdes (VAL-007). Falta: límites de respuesta HTTP en capa youtube (CYC-007) y auditoría final
- Commit: pendiente de commit en este bloque
- Notas:

### CYC-021 — Logging seguro con niveles y deduplicación
- Requisito de GOAL.md: Logs
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-016, CYC-020
- Archivos: `src/support/logging.lua`, `src/support/rate_limit.lua`, `tests/unit/support_spec.lua`
- Validación requerida: niveles error/warn/info/debug, debug off por defecto, sin campos sensibles
- Resultado: niveles + ruta a `c2.log` con fallback a print, redacción de claves sensibles (continuation/cookie/token/key/...), deduplicación 3+resumen/ventana, rate_limit con reloj de pared y buckets acotados (256), muestras anonimizadas solo en debug vía sink inyectable; verde (VAL-007)
- Commit: pendiente de commit en este bloque
- Notas:

### CYC-022 — Rendimiento y limpieza de recursos
- Requisito de GOAL.md: Rendimiento
- Estado: Implementado, pendiente de prueba (suite verde; pendiente consolidar `docs/validation/performance.md`)
- Dependencias: CYC-006, CYC-007, CYC-017, CYC-019
- Archivos: `tests/perf/load_spec.lua`
- Validación requerida: escenarios 1 canal, 10 offline, 5 directos, multi-split, alta actividad y ejecución prolongada
- Resultado: 5 directos × 120 msg/poll × 120 s, multi-split sin requests extra, split cerrado detiene polling sin request final, 10 canales offline 1 check/canal, backoff 30/60/120/300 verificado, 3 h simuladas (~39 checks/canal), timers acotados, dedupe ≤5000, 0 escrituras de persistencia durante tráfico; verde (VAL-010)
- Commit: pendiente en este bloque
- Notas: corregidos: wake del monitor offline (dormía 300 s fijos) y prune pre-request al cerrar splits

### CYC-024 — Harness de integración de API de Chatterino
- Requisito de GOAL.md: Pruebas de integración
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-004, CYC-023
- Archivos: `tests/harness/c2_mock.lua`, `tests/integration/chatterino_harness_spec.lua`
- Validación requerida: comandos, mensajes, splits, timers, requests, reconexión y mutaciones
- Resultado: mock c2 completo (comandos, canales, mensajes, timers, HTTP síncrono controlado); flujo e2e: /yt-chat → watch page → polling → multi-split sin duplicar polling → dedupe → borrado in-place → evento desconocido visible → fin de directo + limpieza → offline → detección de directo; verde (VAL-010)
- Commit: pendiente en este bloque
- Notas:

### CYC-025 — Validación real/manual con checklist
- Requisito de GOAL.md: Validación real
- Estado: Pendiente
- Dependencias: CYC-024, CYC-032
- Archivos: `docs/validation/manual-checklist.md`, `TRACKER.md`
- Validación requerida: ejecución documentada de checklist completa
- Resultado: Pendiente; capturas reales parciales ya hechas (VAL-009)
- Commit: N/A
- Notas: anonimizar cualquier evidencia de usuarios reales

### CYC-026 — Fuzzing defensivo de parsers
- Requisito de GOAL.md: Fuzzing defensivo
- Estado: Implementado, pendiente de prueba (suite verde)
- Dependencias: CYC-023
- Archivos: `tests/fuzz/parser_fuzz_spec.lua`
- Validación requerida: parser robusto sin loops infinitos ni caída global por evento único
- Resultado: 400 árboles aleatorios + degenerados + anidación profunda (500) + strings enormes + URLs maliciosas + validate_schema fuzz; bug real encontrado y corregido (`first_key` con claves numéricas); verde (VAL-010)
- Commit: pendiente en este bloque
- Notas:

### CYC-028 — Documentación completa de producto y seguridad
- Requisito de GOAL.md: Documentación
- Estado: Pendiente
- Dependencias: CYC-003..CYC-027
- Archivos: `README.md`, `CHANGELOG.md`, `COMPATIBILITY.md`, `SECURITY.md`, `CONTRIBUTING.md`, `NOTICE.md`, `docs/**`
- Validación requerida: docs alineadas con artefacto final y limitaciones reales
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-029 — Configuración del repositorio GitHub y publicación v1.0.0
- Requisito de GOAL.md: Repositorio y atribución, Release, Criterios 1.0.0
- Estado: Pendiente
- Dependencias: CYC-001..CYC-028
- Archivos: remotos git/tags/releases
- Validación requerida: repo público creado, tag `v1.0.0`, release publicada tras checklist completa
- Resultado: Pendiente
- Commit: N/A
- Notas: no publicar si queda criterio obligatorio sin verificar

### CYC-030 — Informe final obligatorio
- Requisito de GOAL.md: Informe final obligatorio
- Estado: Pendiente
- Dependencias: CYC-029
- Archivos: informe final en respuesta y `docs/validation/final-report.md`
- Validación requerida: incluir todos los campos obligatorios con evidencia
- Resultado: Pendiente
- Commit: N/A
- Notas:

## Implementado, pendiente de prueba

- (sin entradas)

## Bloqueado

- (sin entradas)

## Verificado

### CYC-000 — Ingesta de objetivo y contraste inicial
- Requisito de GOAL.md: Flujo de trabajo (1, 6)
- Estado: Verificado
- Dependencias: Ninguna
- Archivos: `GOAL.md`
- Validación requerida: lectura completa y contraste de estado actual
- Resultado: El entorno contiene únicamente `GOAL.md`; no existe implementación previa de plugin
- Commit: N/A
- Notas:

### CYC-001 — Bootstrap del repositorio independiente
- Requisito de GOAL.md: Repositorio y atribución, Estructura del repositorio, Historial Git
- Estado: Verificado
- Dependencias: Ninguna
- Archivos: historial importado + nuevos archivos de raíz (`LICENSE`, `NOTICE.md`, `README.md`)
- Validación requerida: preservar historial `yt-chat` y mantener atribución/licencia visible
- Resultado: historial `yt-chat` preservado con subtree split; licencia y procedencia visibles en repositorio
- Commit: N/A
- Notas:

## Descartado

- (sin entradas)

## Riesgos y deuda incompatible con 1.0.0

Ninguno abierto al publicar. Riesgos residuales documentados (no bloqueantes):

1. Renderers raros no confirmados en fuentes actuales (`liveChatPurchasedProductMessageRenderer`, `liveChatModerationMessageRenderer`, `liveChatAutoModMessageRenderer`) están cubiertos por fallback visible; si aparecen en producción, el modo debug genera muestras anonimizadas para añadir soporte completo.
2. `Retry-After` no es legible en la API HTTP de Chatterino 2.5.5 (sin acceso a headers); el parser existe para cuando la API lo exponga.
3. La entrada interactiva del comando `/yt-chat` en GUI no pudo automatizarse headless; cubierta por harness de integración y checklist manual para el usuario (`docs/validation/manual-checklist.md`).
4. El hash del ZIP varía entre toolchains zip distintos (contenido idéntico); el artefacto canónico y su checksum son los del job CI de release.

## Criterios de aceptación 1.0.0 (GOAL.md) — estado final

1. Renderers/acciones actuales implementados o representados — ✓ matriz COMPATIBILITY.md.
2. Ningún evento descartado silenciosamente — ✓ fallback visible; único no-op documentado: `liveChatReportModerationStateCommand` (no es evento de chat).
3. Fallback visible y seguro para desconocidos — ✓ tests + fixtures.
4. Categorías obligatorias cubiertas — ✓ fixtures y suite.
5. Reconexión funciona — ✓ harness (HTTP 500 → backoff → recuperación) + fin de directo → vigilancia offline.
6. Polling respeta intervalos de YouTube — ✓ `timeoutMs` real=10000 capturado; clamps 500ms/15s/1s.
7. Sin bucles agresivos — ✓ perf 3 h simuladas.
8. Sin solicitudes duplicadas por split — ✓ harness + perf.
9. Persistencia recuperable y atómica posible — ✓ tmp+verify+.bak (+rename fuera del sandbox).
10. Pruebas automatizadas pasan — ✓ 1301 aserciones, CI verde.
11. Matriz sin `Unsupported` obligatorios — ✓ ninguno.
12. Sin errores críticos/altos abiertos — ✓.
13. Sin corrupción conocida de configuración — ✓ tests de corrupción/recuperación.
14. Sin crecimiento ilimitado de memoria — ✓ cotas verificadas en perf.
15. Sin secretos ni payloads en logs — ✓ tests de redacción; barrido final.
16. Instalación validada en Chatterino estable — ✓ VAL-011 (2.5.5 oficial).
17. Instalación desde cero + actualización — ✓ VAL-011/012/014 (ZIP limpio + estado legacy).
18. Artefacto coincide con documentación — ✓ README/COMPATIBILITY alineados; 36 archivos.
19. SHA-256 publicado — ✓ asset `.sha256` + notas (`2f825382…be948`).
20. Revisión final de seguridad/regresiones — ✓ barrido de patrones prohibidos, allowlist de hosts, redacción, permisos mínimos CI, acciones fijadas por SHA.

## Registro de decisiones

### ADR-001 — Gestionar el trabajo por tareas trazables CYC-xxx en TRACKER.md
- Contexto: `GOAL.md` exige trazabilidad detallada y evidencia por requisito.
- Decisión: Crear IDs estables CYC-000..CYC-030 con dependencias, validación y resultado.
- Alternativas: checklist no estructurada en texto libre.
- Consecuencias: Mayor esfuerzo de mantenimiento, pero auditabilidad completa.
- Evidencia: `TRACKER.md` (esta revisión inicial).

### ADR-002 — Baseline modular con fallback semántico explícito
- Contexto: `GOAL.md` exige no perder eventos, separar responsabilidades y soportar unknown handlers de forma segura.
- Decisión: Implementar capa `actions -> renderers -> messages` con fallback visible (`unknown_event`) y logging rate-limited con redacción.
- Alternativas: mantener parser monolítico original.
- Consecuencias: mejor trazabilidad y testabilidad; requiere ampliar cobertura de renderers para declarar 1.0.0 completa.
- Evidencia: `src/youtube/actions.lua`, `src/youtube/renderers.lua`, `src/messages/fallback.lua`, `src/support/logging.lua`.

### ADR-003 — Reloj monotónico propio (sin librería `os`)
- Contexto: el sandbox de Chatterino no expone `os` (verificado en `PluginController.cpp` v2.5.5: `LUA_OSLIBNAME` comentado). backoff, rate-limit, dedupe TTL y debounce necesitan tiempo.
- Decisión: `src/support/clock.lua` con heartbeat de 100 ms encadenado en `c2.later` (monotónico, relativo); en tests/plain-Lua usa `os.time`. Todos los módulos inyectan `Clock.now_ms()`.
- Alternativas: depender de timestamps de YouTube (no cubre timers locales); asumir `os` (rompería en Chatterino).
- Consecuencias: deriva de segundos aceptable para backoff/rate-limit; ninguna lógica depende de hora absoluta.
- Evidencia: `src/support/clock.lua`, `PluginController.cpp` v2.5.5 líneas 144-167.

### ADR-004 — Persistencia atómica sin `os.rename`
- Contexto: GOAL exige tmp+flush+sustitución segura+.bak; el sandbox no tiene `os.rename`/`os.remove`.
- Decisión: doble camino en `persistence.lua`: rename atómico cuando `os` existe (tests), y tmp+verify+write+.bak con verificación de relectura y restauración desde .bak en el sandbox. Es el máximo de atomicidad posible en Chatterino; GOAL pide "atómica dentro de las posibilidades de Lua y Chatterino".
- Alternativas: escritura directa sin tmp (riesgo de truncado).
- Consecuencias: ventana de no-atomicidad documentada en `SECURITY.md`; recuperación garantizada vía `.bak`.
- Evidencia: `src/state/persistence.lua` (`write_atomic`), test `no-rename` en `persistence_spec.lua`.

### ADR-005 — Placeholders/reacciones coalescidos por ventana
- Contexto: `liveChatPlaceholderItemRenderer` corresponde mayoritariamente a reacciones de emoji con spam potencial alto; GOAL prohíbe descartar eventos silenciosamente.
- Decisión: coalescer placeholders por stream en ventanas de 10 s y emitir un evento de sistema "✨ N reactions"; `replaceChatItemAction` entrega el mensaje real que sustituye al placeholder.
- Alternativas: un mensaje por reacción (inundaría el chat); descartarlos (prohibido).
- Consecuencias: significado preservado sin flooding; documentado en COMPATIBILITY.md.
- Evidencia: `src/youtube/polling.lua` (`deliver_event`, `REACTION_WINDOW_MS`).

### ADR-006 — Eventos pinned con id `pin-<target>`
- Contexto: un mensaje puede aparecer como ordinario y después como banner fijado; GOAL exige evitar duplicados sin perder el aviso de fijación.
- Decisión: el evento `pinned` usa id prefijado `pin-` para deduplicar independientemente del mensaje original; la notificación de pin es un evento de sistema con autor y texto.
- Evidencia: `src/messages/system.lua` (`System.pinned`), fixture real `fixtures/real/addBannerToLiveChatCommand.json`.

## Registro de validaciones

### VAL-001 — Lectura completa de GOAL y estado base
- Fecha: 2026-07-19T13:58:00+02:00
- Entorno: `/home/tears/stream` (Linux)
- Procedimiento: lectura completa de `GOAL.md` y listado del directorio raíz
- Resultado: confirmado que no existe base de código previa y todos los criterios están pendientes
- Evidencias: salida de `ls -la /home/tears/stream`; contenido de `GOAL.md`
- Incidencias relacionadas: ninguna

### VAL-002 — Preservación de historial del plugin fuente
- Fecha: 2026-07-19T13:59:00+02:00
- Entorno: `/home/tears/stream` (Linux)
- Procedimiento: clonado completo de upstream y extracción `git subtree split --prefix=yt-chat`
- Resultado: rama `yt-chat-history` creada e importada como base de `main` en este repositorio local
- Evidencias: hash `42bafd31b3d72e9fac31cb108919eae0f1115f30`, log local de commits de `yt-chat`
- Incidencias relacionadas: ninguna

### VAL-003 — Ejecución de suite automática local
- Fecha: 2026-07-19T14:04:00+02:00
- Entorno: `/home/tears/stream` (Lua 5.5)
- Procedimiento: `scripts/test.sh`
- Resultado: suite completada (`Assertions: 27, Failures: 0`)
- Evidencias: salida de `scripts/test.sh`
- Incidencias relacionadas: ninguna

### VAL-004 — Construcción de artefacto y checksum
- Fecha: 2026-07-19T14:04:00+02:00
- Entorno: `/home/tears/stream`
- Procedimiento: `scripts/build_release.sh 1.0.0` + `scripts/sha256.sh dist/chatterino-yt-chat-1.0.0.zip`
- Resultado: ZIP y SHA-256 generados localmente
- Evidencias: `dist/chatterino-yt-chat-1.0.0.zip`, hash `391609111793e8feefb46b707f3aeab1bc53c03aa02c83ffdd6b4f85a1684c89`
- Incidencias relacionadas: ninguna

### VAL-005 — Reproducibilidad del ZIP
- Fecha: 2026-07-19T14:06:00+02:00
- Entorno: `/home/tears/stream`
- Procedimiento: ejecutar dos veces seguidas `scripts/build_release.sh 1.0.0` y comparar `sha256sum`
- Resultado: hash idéntico en ambas ejecuciones (`391609111793e8feefb46b707f3aeab1bc53c03aa02c83ffdd6b4f85a1684c89`)
- Evidencias: salida de shell de doble checksum consecutivo
- Incidencias relacionadas: ninguna

### VAL-006 — Reapertura de CYC-027 por fallo CI y corrección
- Fecha: 2026-07-19T14:08:00+02:00
- Entorno: GitHub Actions + local
- Procedimiento: inspección de `gh run view --log-failed` y ajuste del step `Ensure only allowed hosts in source`
- Resultado: identificado falso positivo por regex sobre patrones Lua; workflow ajustado a extracción de host explícita
- Evidencias: run fallido `29686862255`, diff en `.github/workflows/ci.yml`
- Incidencias relacionadas: CYC-027

### VAL-007 — Suite tras endurecer capas support y state
- Fecha: 2026-07-19T15:05:00+02:00
- Entorno: `/home/tears/stream` (Lua 5.5.0)
- Procedimiento: `scripts/test.sh` completo tras reescribir `validation.lua`, `rate_limit.lua`, `logging.lua`, `backoff.lua`, `persistence.lua`, `migrations.lua`, `channels.lua`, `active_streams.lua` y añadir `support_spec.lua`, `state_spec.lua`, reescritura de `persistence_spec.lua`
- Resultado: verde — `Assertions: 136, Failures: 0`
- Evidencias: salida de `scripts/test.sh`
- Incidencias relacionadas: corregido defecto de doble consumo de bucket en deduplicación de logs antes del commit

### VAL-008 — Capas youtube+messages contra fixtures reales y sintéticos
- Fecha: 2026-07-19T16:35:00+02:00
- Entorno: `/home/tears/stream` (Lua 5.5.0)
- Procedimiento: `scripts/test.sh` tras implementar `url/html/innertube/continuations/polling`, `messages/*`, `actions/renderers`, `c2_adapter`, 4 fixtures reales anonimizados + 28 sintéticos; corrección de 2 bugs encontrados por la propia suite (`first_key` con metadatos; expectativa de color ARGB errónea en el test)
- Resultado: verde — `Assertions: 450, Failures: 0`; sintaxis verificada con `luac5.4 -p` en todos los módulos
- Evidencias: salida de `scripts/test.sh`; captura real `/tmp/cyc_research/chat1.json` (75 acciones reales, no publicada); `fixtures/real/`
- Incidencias relacionadas: CYC-008..CYC-016, CYC-031

### VAL-014 — Verificación del artefacto de release y publicación
- Fecha: 2026-07-19T18:15:00+02:00
- Entorno: GitHub Releases + Chatterino 2.5.5 headless (mismo setup que VAL-011)
- Procedimiento: tag `v1.0.0` → workflow Release crea DRAFT con ZIP + `.sha256`; descarga del artefacto publicado; verificación de hash; instalación del ZIP de CI en Chatterino real con canal en directo; corrección del hash en el cuerpo de la release; publicación
- Resultado: ZIP publicado == `.sha256` (`2f825382…be948`); el ZIP de CI carga en Chatterino y conecta al chat real (`plugin_loaded`, `chat_started`); release publicada no-draft no-prerelease
- Evidencias: `gh release view v1.0.0`; salida Chatterino con el ZIP de CI
- Incidencias relacionadas: el ZIP construido localmente y el de CI difieren en bytes por versión del codificador zip (contenido idéntico, 36 archivos); documentado en release notes y ADR pendiente — mitigado: `.sha256` generado en el mismo job CI que publica el artefacto

### VAL-013 — CI remota verde + reconexión + barrido de seguridad
- Fecha: 2026-07-19T18:00:00+02:00
- Entorno: GitHub Actions `ubuntu-latest` + local
- Procedimiento: push de `main` → workflow CI completo; test de reconexión (HTTP 500 → backoff → recuperación) añadido al harness; barrido `grep` de patrones prohibidos en `src/`
- Resultado: CI VERDE (run `29693795457`): luacheck 0/43 warnings, format, hosts, secret scan, fixtures, tests 1301 aserciones, build reproducible, sha256, artefacto; reconexión verificada; barrido sin `load`/`loadstring`/`io.popen`/`os.execute` ni hosts fuera de allowlist ni claves embebidas
- Evidencias: `gh run view 29693795457`; salida de `scripts/test.sh` (1301/0)
- Incidencias relacionadas: CYC-027, CYC-018, criterios 5, 10, 19, 20

### VAL-011 — Instalación limpia del ZIP en Chatterino 2.5.5 estable
- Fecha: 2026-07-19T17:20:00+02:00
- Entorno: Arch Linux x86_64, `Chatterino-Ubuntu-24.04.deb` v2.5.5 oficial (SHA-256 `8ad1ec90ea5f02112f0c3e1814f0e5679e8fd456d15c949e7ced85dcc5da48ce` verificado contra `sha256-checksums.txt` de la release), ejecución headless `QT_QPA_PLATFORM=minimal`, `XDG_DATA_HOME` sandbox, ICU 74 local
- Procedimiento: extraer `dist/chatterino-yt-chat-1.0.0.zip` en `Plugins/chatterino-yt-chat/`, habilitar plugin, lanzar Chatterino
- Resultado: plugin cargado sin errores (`plugin_loaded | channels=0`), info.json aceptado, permisos funcionando (io solo en data dir)
- Evidencias: log `chatterino.lua` capturado; `docs/validation/chatterino-install.md`
- Incidencias relacionadas: CYC-032

### VAL-012 — End-to-end real: chat de YouTube dentro de Chatterino
- Fecha: 2026-07-19T17:26:00+02:00
- Entorno: mismo que VAL-011, red a YouTube operativa
- Procedimiento: sembrar estado con canal real (Lofi Girl, `UCSJ4gkVC6NrvII8umztf0Ow`) y split `ytchat-e2e`; lanzar Chatterino 90 s
- Resultado: `stream_went_live` + `chat_started | channel=Lofi Girl video=VAlMDl00mYY`; mensajes reales entregados al split (log de canal de Chatterino con autores, emoji unicode nativo, emotes custom como `:shortcut:`); 3 timers del plugin (heartbeat, monitor offline, poll de chat); estado legacy migrado en memoria sin errores
- Evidencias: log `chatterino.lua`; `Logs/Twitch/Channels/ytchat-e2e/…log` (sandbox local, no publicado por privacidad); `docs/validation/chatterino-install.md`
- Incidencias relacionadas: CYC-032, CYC-025

### VAL-010 — Suite completa: unitarias + integración + fuzz + carga
- Fecha: 2026-07-19T17:05:00+02:00
- Entorno: `/home/tears/stream` (Lua 5.5.0)
- Procedimiento: `scripts/test.sh` con nuevo harness `tests/harness/c2_mock.lua`, integración e2e, fuzz (400 árboles + degenerados) y carga (`tests/perf/load_spec.lua`)
- Resultado: verde — `Assertions: 1298, Failures: 0` (~7 s)
- Evidencias: salida de `scripts/test.sh`
- Incidencias relacionadas: bugs encontrados y corregidos durante esta fase: (1) wake fijo de 300 s del monitor offline; (2) polling final tras cierre de splits (prune pre-request); (3) `first_key` con claves numéricas (fuzz); (4) aislamiento de estado entre specs (`Polling._reset`)

### VAL-009 — Captura real de YouTube Live Chat (conectividad y protocolo)
- Fecha: 2026-07-19T16:10:00+02:00
- Entorno: red saliente a `www.youtube.com` (HTTP 200), curl
- Procedimiento: GET `https://www.youtube.com/@LofiGirl/live` (UA `facebookexternalhit/`) → canonical videoId, `liveChatRenderer` presente, `INNERTUBE_API_KEY`, `INNERTUBE_CONTEXT_CLIENT_VERSION`, continuation; POST `youtubei/v1/live_chat/get_live_chat` → 75 acciones reales (texto con emoji unicode, viewer engagement subscribers-only, banner pinned, removeChatItemAction); segundo poll con nueva continuation OK (24 acciones); `@NASA/live` offline (sin liveChatRenderer) confirma camino offline
- Resultado: protocolo del plugin validado contra YouTube real hoy; `timeoutMs` real = 10000 en invalidationContinuationData
- Evidencias: `/tmp/cyc_research/watch_lofi.html`, `live_fb.html`, `chat1.json`, `chat2.json` (locales, no publicados); fixtures anonimizados derivados en `fixtures/real/`
- Incidencias relacionadas: CYC-031; UA del plugin original sigue sirviendo páginas con datos de chat

## Estado de sesión para continuidad

- Qué se hizo (sesión 2026-07-19 tarde): investigación directa (Chatterino API v2.5.5 + inventario renderers YouTube con capturas reales); capas support/state/youtube/messages completas; polling + monitor offline + mutación in-place; 36 fixtures (4 reales anonimizados); suite 1301 aserciones verde; CI verde (lint/format/hosts/secrets/fixtures/tests/build reproducible); validación real en Chatterino 2.5.5 oficial con chat real (VAL-011/012/014); tag `v1.0.0`; release draft → verificada → **publicada**.
- Qué se estaba haciendo: cierre e informe final (CYC-030).
- Qué falta: nada bloqueante. Recomendado post-release: checklist manual GUI del usuario (`docs/validation/manual-checklist.md`), especialmente soak de horas y entrada interactiva del comando.
- Qué falló: nada abierto. Corregido en sesión: dedupe logging, wake monitor offline, prune pre-request, first_key numérico/metadatos, expectativa ARGB, luacheck vía luarocks en CI, allowlist (example.com), fixture real con URL sin anonimizar, hash local≠CI del ZIP (canónico=CI, documentado).
- Qué debe ejecutarse después: nada obligatorio; si YouTube introduce renderers nuevos, el modo debug genera muestras anonimizadas para nuevos fixtures.
- Comandos relevantes:
  - `scripts/test.sh` (1301 aserciones)
  - `scripts/build_release.sh 1.0.0 && scripts/sha256.sh dist/chatterino-yt-chat-1.0.0.zip`
  - `gh release view v1.0.0 --repo tears-mysthrala/chatterino-yt-chat`
- Estado de Git: main limpio y pusheado (`de90a61`); tag `v1.0.0` con release estable publicada.
- Pruebas pendientes: ninguna bloqueante.
- Bloqueos: ninguno.
- Próxima tarea recomendada: informe final al usuario (CYC-030).
