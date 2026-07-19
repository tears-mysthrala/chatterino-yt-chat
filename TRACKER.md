## Estado global

- Objetivo: `chatterino-yt-chat v1.0.0`
- Estado actual: En desarrollo
- Última actualización: 2026-07-19T14:06:00+02:00
- Rama actual: main
- Último commit revisado: `42bafd31b3d72e9fac31cb108919eae0f1115f30`
- Criterios obligatorios verificados: 3/20
- Bloqueos activos: 0

## En curso

### CYC-029 — Configuración del repositorio GitHub y publicación v1.0.0
- Requisito de GOAL.md: Repositorio y atribución, Release, Criterios 1.0.0
- Estado: En curso
- Dependencias: CYC-001..CYC-028
- Archivos: remotos git/tags/releases
- Validación requerida: repo público creado, tag `v1.0.0`, release publicada tras checklist completa
- Resultado: Pendiente
- Commit: e104cf4
- Notas: no se publicará release estable hasta completar criterios pendientes

### CYC-023 — Sistema de pruebas unitarias + fixtures anonimizados
- Requisito de GOAL.md: Pruebas automatizadas
- Estado: Implementado, pendiente de prueba
- Dependencias: CYC-003, CYC-004
- Archivos: `tests/**`, `fixtures/**`, `scripts/test.sh`
- Validación requerida: ejecución de suite con casos de renderers/acciones/continuations y robustez
- Resultado: Suite base ejecuta unitarias + integración simulada + fuzz ligero
- Commit: e104cf4
- Notas: cobertura aún parcial frente a todos los renderers/eventos exigidos

### CYC-027 — CI, release automation y packaging reproducible
- Requisito de GOAL.md: CI, Release
- Estado: Implementado, pendiente de prueba
- Dependencias: CYC-023, CYC-024
- Archivos: `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `scripts/build_release.sh`, `scripts/sha256.sh`
- Validación requerida: ZIP reproducible + SHA256 + checks de versión/tag + draft release
- Resultado: pipelines y scripts creados; build local reproducible validado con hash estable en builds consecutivos
- Commit: e104cf4
- Notas: falta validación en GitHub Actions real y creación de draft release remota

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

### CYC-002 — Investigación de API de plugins de Chatterino
- Requisito de GOAL.md: Compatibilidad de Chatterino
- Estado: Pendiente
- Dependencias: CYC-001
- Archivos: `docs/chatterino-plugin-api.md`, `README.md`, `COMPATIBILITY.md`
- Validación requerida: versión mínima compatible documentada con capacidades y limitaciones verificables
- Resultado: Pendiente
- Commit: N/A
- Notas: Debe basarse en documentación oficial/implementaciones auditables

### CYC-003 — Matriz completa de acciones/renderers de YouTube Live Chat
- Requisito de GOAL.md: Compatibilidad real, Acciones/renderers desconocidos
- Estado: Pendiente
- Dependencias: CYC-001
- Archivos: `COMPATIBILITY.md`, `docs/research/youtube-live-chat-renderers.md`
- Validación requerida: matriz con acción, renderer, handler, fixture, resultado esperado y estado `Full`/`Degraded by Chatterino API`
- Resultado: Pendiente
- Commit: N/A
- Notas: `Unsupported` no permitido para tipos obligatorios en release 1.0.0

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
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/text.lua`, `src/messages/emotes.lua`, `src/messages/badges.lua`, `src/messages/builder.lua`, `tests/**`
- Validación requerida: cobertura de runs mixtos, emotes nativos/canal, unicode, enlaces, badges y rol de autor
- Resultado: Pendiente
- Commit: N/A
- Notas: no perder runs sin `text`

### CYC-009 — Super Chat/Super Sticker y eventos monetarios
- Requisito de GOAL.md: Super Chats y aportaciones económicas
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/monetary.lua`, `src/youtube/renderers.lua`, `tests/**`
- Validación requerida: importe, moneda, texto, nivel visual y fallback semántico
- Resultado: Pendiente
- Commit: N/A
- Notas: sin conversiones monetarias

### CYC-010 — Membresías, regalos y eventos de nivel
- Requisito de GOAL.md: Membresías
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/memberships.lua`, `src/youtube/renderers.lua`, `tests/**`
- Validación requerida: nuevas/renovación/antigüedad/regalos/receptores/nivel/cambios
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-011 — Moderación y mutaciones de mensajes
- Requisito de GOAL.md: Moderación y mutaciones visibles
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004, CYC-007
- Archivos: `src/messages/moderation.lua`, `src/state/active_streams.lua`, `src/youtube/actions.lua`, `tests/**`
- Validación requerida: eliminación/sustitución/marcado/actualización con ID o fallback inequívoco
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-012 — Fijados, destacados y banners sin duplicados
- Requisito de GOAL.md: Mensajes fijados y destacados
- Estado: Pendiente
- Dependencias: CYC-003, CYC-011
- Archivos: `src/messages/system.lua`, `src/state/active_streams.lua`, `tests/**`
- Validación requerida: pin/unpin/cambio/banner/highlight y deduplicación mensaje-banner
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-013 — Encuestas, Q&A e interactivos en modo lectura
- Requisito de GOAL.md: Encuestas, preguntas y eventos interactivos
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/polls.lua`, `src/youtube/actions.lua`, `tests/**`
- Validación requerida: opciones, recuentos/porcentajes, updates, cierre y mensajes de sistema
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-014 — Redirecciones, estado del directo y sistema
- Requisito de GOAL.md: Redirecciones y eventos del directo
- Estado: Pendiente
- Dependencias: CYC-003, CYC-007
- Archivos: `src/messages/system.lua`, `src/youtube/actions.lua`, `tests/**`
- Validación requerida: redirect/raid/live status/chat restrictions/slow mode/end stream
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-015 — Placeholders, reacciones y efectos
- Requisito de GOAL.md: Placeholders, reacciones y efectos
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/system.lua`, `src/youtube/actions.lua`, `tests/**`
- Validación requerida: placeholder->resultado final, reacciones y efectos semánticos
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-016 — Fallback seguro para acciones/renderers desconocidos
- Requisito de GOAL.md: Acciones y renderers desconocidos
- Estado: Pendiente
- Dependencias: CYC-003, CYC-004
- Archivos: `src/messages/fallback.lua`, `src/support/logging.lua`, `src/support/rate_limit.lua`, `tests/**`
- Validación requerida: mensaje visible, redacción de sensibles, rate limit y modo diagnóstico explícito
- Resultado: Pendiente
- Commit: N/A
- Notas: no loggear payload completo en producción

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
- Estado: Pendiente
- Dependencias: CYC-004
- Archivos: `src/state/persistence.lua`, `src/state/migrations.lua`, `tests/**`
- Validación requerida: write-temp+flush+replace+.bak+recovery+schema+debounce+no concurrent write
- Resultado: Pendiente
- Commit: N/A
- Notas: no persistir continuation/API key/payloads/chat content

### CYC-020 — Seguridad y validación de superficie de red/entrada
- Requisito de GOAL.md: Seguridad y privacidad
- Estado: Pendiente
- Dependencias: CYC-005, CYC-007, CYC-019
- Archivos: `src/support/validation.lua`, `SECURITY.md`, `tests/**`
- Validación requerida: allowlist de hosts, límites de tamaños/tipos y sin eval/código remoto
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-021 — Logging seguro con niveles y deduplicación
- Requisito de GOAL.md: Logs
- Estado: Pendiente
- Dependencias: CYC-016, CYC-020
- Archivos: `src/support/logging.lua`, `tests/**`, `README.md`
- Validación requerida: niveles error/warn/info/debug, debug off por defecto, sin campos sensibles
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-022 — Rendimiento y limpieza de recursos
- Requisito de GOAL.md: Rendimiento
- Estado: Pendiente
- Dependencias: CYC-006, CYC-007, CYC-017, CYC-019
- Archivos: `tests/perf/**`, `docs/validation/performance.md`
- Validación requerida: escenarios 1 canal, 10 offline, 5 directos, multi-split, alta actividad y ejecución prolongada
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-024 — Harness de integración de API de Chatterino
- Requisito de GOAL.md: Pruebas de integración
- Estado: Pendiente
- Dependencias: CYC-004, CYC-023
- Archivos: `tests/integration/**`, `tests/harness/**`
- Validación requerida: comandos, mensajes, splits, timers, requests, reconexión y mutaciones
- Resultado: Pendiente
- Commit: N/A
- Notas:

### CYC-025 — Validación real/manual con checklist
- Requisito de GOAL.md: Validación real
- Estado: Pendiente
- Dependencias: CYC-024
- Archivos: `docs/validation/manual-checklist.md`, `TRACKER.md`
- Validación requerida: ejecución documentada de checklist completa
- Resultado: Pendiente
- Commit: N/A
- Notas: anonimizar cualquier evidencia de usuarios reales

### CYC-026 — Fuzzing defensivo de parsers
- Requisito de GOAL.md: Fuzzing defensivo
- Estado: Pendiente
- Dependencias: CYC-023
- Archivos: `tests/fuzz/**`
- Validación requerida: parser robusto sin loops infinitos ni caída global por evento único
- Resultado: Pendiente
- Commit: N/A
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

1. No hay validación real en binario estable de Chatterino dentro de este entorno; pendiente CYC-025.
2. La creación/publicación en GitHub puede quedar bloqueada si no hay credenciales activas en CLI.
3. La validación de instalación real en Chatterino puede quedar bloqueada por ausencia de binario/entorno GUI en esta máquina.
4. Las pruebas con chats reales de YouTube dependen de conectividad y estabilidad de endpoints públicos.

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

## Estado de sesión para continuidad

- Qué se hizo: importación histórica del plugin, refactor modular en `src/`, documentación base, CI base, pruebas locales y build+sha local.
- Qué se estaba haciendo: ampliación de cobertura funcional y cierre de gaps críticos de compatibilidad.
- Qué falta: validación real en Chatterino, investigación exhaustiva de renderers/acciones actuales y cierre de todos los criterios 1..20.
- Qué falló: aún no hay validación end-to-end sobre instancia real de Chatterino ni publicación remota.
- Qué debe ejecutarse después:
  1. ampliar parser/fixtures para cubrir categorías pendientes (membresías regalo, reacciones, redirects, estados de chat, etc.);
  2. ejecutar checklist manual con Chatterino real y registrar evidencia;
  3. crear repositorio remoto GitHub, push, validar Actions y preparar draft release.
- Comandos relevantes:
  - `scripts/test.sh`
  - `scripts/build_release.sh 1.0.0`
  - `scripts/sha256.sh dist/chatterino-yt-chat-1.0.0.zip`
- Estado de Git: repositorio inicializado en `main`, cambios locales grandes sin commit consolidado.
- Pruebas pendientes: matriz completa de renderers/acciones, integración real en Chatterino, pruebas de carga prolongadas.
- Bloqueos: ninguno activo.
- Próxima tarea recomendada: CYC-003 (cerrar matriz completa con cobertura real y fixtures por acción/renderer).
