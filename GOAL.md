Quiero convertir el plugin experimental `yt-chat` del repositorio original:

https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat

en un proyecto independiente, mantenible y preparado para una primera versión estable:

```text
chatterino-yt-chat v1.0.0
```

Debes crear y publicar el nuevo repositorio en mi cuenta de GitHub con el nombre exacto:

```text
chatterino-yt-chat
```

El repositorio debe ser independiente del monorepo original y contener únicamente este plugin, sus pruebas, documentación, empaquetado y automatización de release. Conserva de forma visible la licencia MIT, la autoría original y el enlace al proyecto del que deriva.

No quiero una beta, una alfa, una prueba de concepto ni una simple subida de versión. Debes implementar todo lo necesario para que pueda considerarse una versión `1.0.0` estable y plenamente utilizable como visor de chat de YouTube dentro de Chatterino.

# Definición del producto

`chatterino-yt-chat` debe convertir Chatterino en un visor completo, fiable y persistente del chat de los directos de YouTube.

Su alcance es estrictamente de lectura. No debe escribir ni ejecutar acciones de moderación, pero debe representar dentro de Chatterino toda la información visible y operacionalmente relevante del chat.

Las personas moderadoras escribirán, responderán y moderarán desde YouTube Studio u otras herramientas. Este plugin debe permitir que la persona responsable del seguimiento pueda permanecer en Chatterino y observar correctamente todo lo que sucede en el chat.

# Alcance obligatorio de la versión 1.0.0

La release `1.0.0` debe soportar todos los tipos de mensajes, eventos y mutaciones de chat disponibles actualmente mediante el protocolo de YouTube utilizado por el plugin.

No aceptes una implementación parcial basada únicamente en `liveChatTextMessageRenderer`.

Debes investigar las estructuras actuales de YouTube Live Chat e implementar compatibilidad con todos los renderers y acciones observables y documentados en fuentes fiables, ejemplos reales, respuestas capturadas de prueba o implementaciones abiertas auditables.

Como mínimo, la versión estable debe soportar correctamente las siguientes categorías.

## 1. Mensajes ordinarios

Representar:

* Nombre de la persona autora.
* Texto completo.
* Fragmentos múltiples de texto.
* Emotes nativos de YouTube.
* Emojis Unicode.
* Enlaces.
* Marcas temporales.
* Identificador estable del mensaje.
* Canal de origen cuando un split combina varios chats.
* Insignias de la persona autora.
* Color o formato apropiado sin perjudicar la legibilidad.
* Mensajes enviados por la propietaria o propietario del canal.
* Mensajes de moderadores.
* Mensajes de miembros.
* Cuentas verificadas.

No perder silenciosamente ningún `run` que no contenga una propiedad `text`.

## 2. Emotes e imágenes

Implementar representación completa de:

* Emotes estándar de YouTube.
* Emotes personalizados del canal.
* Emojis Unicode.
* Imágenes incluidas en eventos de chat.
* Stickers asociados a Super Stickers.
* Badges e insignias cuando la API de mensajes de Chatterino permita representarlos.

Cuando Chatterino permita registrar o mostrar imágenes remotas de manera segura, utilizarlas mediante HTTPS y caché razonable.

Cuando una imagen no pueda mostrarse:

* Utilizar un fallback textual descriptivo.
* No omitir el evento.
* No bloquear el resto del mensaje.
* No descargar ni ejecutar contenido arbitrario.

## 3. Super Chats y aportaciones económicas

Mostrar de manera diferenciada:

* Super Chat.
* Super Sticker.
* Importe.
* Moneda.
* Texto mostrado por YouTube.
* Nivel visual o color asociado cuando esté disponible.
* Nombre, insignias y avatar o emote cuando sea compatible.
* Duración o fijación cuando esa información forme parte del evento.
* Mensajes de agradecimiento u otros mensajes de sistema relacionados.

No realizar cálculos de conversión monetaria.

No inventar equivalencias de moneda.

## 4. Membresías

Representar:

* Nueva membresía.
* Renovación.
* Antigüedad de membresía.
* Mensaje de miembro.
* Membresías regaladas.
* Recepción de membresía regalada.
* Número de membresías regaladas.
* Nivel de membresía cuando esté disponible.
* Insignias asociadas.
* Eventos de actualización o cambio de nivel.
* Mensajes de sistema relacionados.

## 5. Moderación y mutaciones visibles

Aunque el plugin no debe ejecutar moderación, sí debe reflejar los cambios que se produzcan:

* Mensaje eliminado.
* Mensajes eliminados por autor.
* Persona ocultada o eliminada del chat.
* Timeout cuando el evento sea visible.
* Retirada de mensajes.
* Sustitución de mensajes.
* Actualización de mensajes.
* Eliminación de un elemento previamente renderizado.
* Marcado o desmarcado de mensajes.
* Eventos de moderación representados por YouTube.
* Cambios de estado que afecten a mensajes ya mostrados.

Cuando Chatterino permita modificar o retirar un mensaje existente mediante su identificador, utiliza esa capacidad.

Cuando no sea posible modificarlo directamente:

* Añade un evento informativo inequívoco.
* Incluye el identificador o autor afectado cuando esté disponible.
* No presentes como activo un mensaje que YouTube haya retirado sin dejar ninguna indicación.

## 6. Mensajes fijados y destacados

Implementar:

* Mensajes fijados.
* Cambio de mensaje fijado.
* Desfijado.
* Banner de mensaje fijado.
* Mensajes destacados por YouTube.
* Mensajes de propietaria o moderación resaltados.
* Actualización del estado de fijación.

Evitar insertar duplicados cuando un mismo mensaje aparezca primero como mensaje ordinario y después como banner fijado.

## 7. Encuestas, preguntas y eventos interactivos

Representar en modo lectura:

* Encuestas.
* Opciones.
* Recuentos o porcentajes cuando estén disponibles.
* Actualizaciones de resultados.
* Finalización de encuesta.
* Preguntas destacadas.
* Q&A.
* Eventos interactivos equivalentes.
* Mensajes automáticos relacionados.

Como el plugin es de solo lectura, no necesita permitir votar ni responder, pero la información debe mostrarse completa y actualizarse de forma comprensible.

## 8. Redirecciones y eventos del directo

Representar eventos como:

* Live redirect.
* Raid o redirección equivalente.
* Inicio de redirección.
* Avisos previos a una redirección.
* Cambio de vídeo activo.
* Estrenos.
* Cuenta atrás.
* Inicio del directo.
* Finalización del directo.
* Mensajes de sistema relevantes.
* Cambios de estado del chat.
* Chat deshabilitado.
* Chat exclusivo para miembros.
* Modo lento y cambios de modo cuando sean visibles.
* Limitaciones de participación informadas por YouTube.

## 9. Placeholders, reacciones y efectos

Implementar o representar de forma segura:

* Placeholders temporales.
* Reacciones de emoji.
* Efectos de celebración.
* Animaciones o efectos que tengan significado semántico.
* Recuentos actualizados.
* Sustitución de placeholders por su resultado final.
* Acciones de actualización asociadas.

No es necesario reproducir animaciones complejas dentro de Chatterino, pero debe mostrarse su contenido o significado sin perder el evento.

## 10. Acciones y renderers desconocidos

La compatibilidad completa con la versión actual no significa asumir que YouTube nunca cambiará.

Implementa un sistema genérico y seguro para cualquier renderer o acción desconocida:

* Detectar el nombre exacto del renderer o acción.
* Extraer de forma defensiva cualquier texto, autor, importe, etiqueta, timestamp o imagen reconocible.
* Mostrar un mensaje de sistema legible indicando que se recibió un evento no soportado.
* No omitirlo silenciosamente.
* No imprimir el payload completo en producción.
* Aplicar rate limiting a los logs.
* Permitir activar un modo de diagnóstico explícito y desactivado por defecto.
* En modo diagnóstico, redactar claves, continuations, cookies y campos sensibles antes de guardar muestras.
* Generar fixtures anonimizados que puedan añadirse después a las pruebas.

Un evento desconocido no debe bloquear, reiniciar ni detener el chat.

# Compatibilidad real, no nominal

Antes de declarar `1.0.0`, debes crear una matriz de compatibilidad con:

* Nombre de la acción Innertube.
* Nombre del renderer.
* Función que lo procesa.
* Tipo de mensaje generado en Chatterino.
* Fixture de prueba asociado.
* Resultado esperado.
* Estado de soporte.
* Limitaciones de representación impuestas por Chatterino.

La matriz debe incluir todos los renderers y acciones encontrados durante la investigación.

No marques un tipo como soportado si únicamente se ignora o se imprime en consola.

Estados permitidos en la matriz:

* `Full`: toda la información semántica relevante se representa.
* `Degraded by Chatterino API`: toda la información se conserva, pero existe una limitación visual demostrada de Chatterino.
* `Unsupported`: no permitido para publicar `1.0.0`, salvo que se demuestre que el evento no pertenece al chat de solo lectura o ya no existe en la versión actual de YouTube.

La release `1.0.0` no puede contener entradas obligatorias marcadas como `Unsupported`.

# Arquitectura

Refactoriza el plugin para que las responsabilidades queden separadas y auditables.

La arquitectura recomendada debe incluir módulos equivalentes a:

```text
src/
  init.lua
  commands.lua
  youtube/
    url.lua
    html.lua
    innertube.lua
    continuations.lua
    polling.lua
    actions.lua
    renderers.lua
  messages/
    builder.lua
    text.lua
    emotes.lua
    badges.lua
    monetary.lua
    memberships.lua
    moderation.lua
    polls.lua
    system.lua
    fallback.lua
  state/
    channels.lua
    active_streams.lua
    persistence.lua
    migrations.lua
  support/
    logging.lua
    backoff.lua
    rate_limit.lua
    validation.lua
```

Puedes adaptar la estructura a las restricciones reales del cargador de plugins de Chatterino, pero evita mantener toda la lógica mezclada en unos pocos archivos globales.

No sobrearquitectures el proyecto ni añadas abstracciones sin una función concreta.

# Descubrimiento de canales y directos

Aceptar como mínimo:

* URL completa de un vídeo.
* URL corta de YouTube cuando pueda resolverse de manera segura.
* URL `/watch?v=`.
* URL `/live/`.
* URL `/channel/<id>`.
* URL `/@handle`.
* URL de la pestaña `/live`.
* URLs con parámetros adicionales inocuos.

Normaliza todas las URLs.

Permite únicamente HTTPS y hosts oficiales de YouTube necesarios.

No permitas redirecciones hacia hosts arbitrarios.

Para canales offline:

* Conservar el canal configurado.
* Detectar futuros directos.
* No duplicar canales equivalentes introducidos mediante distintas URL.
* Resolver y persistir un identificador estable de canal.
* Evitar peticiones duplicadas por split.

# Polling offline

Implementar backoff por canal:

* Inicio: 30 segundos.
* Después: 60 segundos.
* Después: 120 segundos.
* Máximo: 300 segundos.
* Reinicio cuando se detecta un directo.
* Jitter razonable.
* Estado separado por canal.
* Una única comprobación por canal independientemente del número de splits.
* Sin timers paralelos duplicados.
* Sin busy loops.

Debe existir una opción de configuración documentada para ajustar estos límites dentro de rangos seguros.

# Polling del chat

Utilizar el intervalo indicado por YouTube mediante:

* `invalidationContinuationData.timeoutMs`
* `timedContinuationData.timeoutMs`
* Cualquier continuation actual equivalente identificada durante la investigación.

Aplicar:

* Mínimo defensivo: 500 ms.
* Máximo normal: 15 segundos.
* Fallback: 1.000 ms.
* Jitter pequeño.
* Un único polling activo por `videoId`.
* Distribución a todos los splits asociados.
* Cancelación limpia cuando no quedan splits.
* Reanudación limpia tras interrupciones.
* Prevención de solicitudes concurrentes para el mismo stream.

No fijar un intervalo agresivo ignorando los valores de YouTube.

# Continuations

Soportar todas las continuations actuales relevantes del chat, incluyendo como mínimo:

* Invalidation continuation.
* Timed continuation.
* Replay continuation cuando proceda.
* Live chat continuation.
* Continuations de actualización.
* Continuations alternativas encontradas durante las pruebas.

El parser debe:

* Diferenciar token e intervalo.
* Validar tipos y rangos.
* Evitar reutilizar tokens expirados.
* Evitar crear dos solicitudes con la misma continuation simultáneamente.
* Recuperarse de continuations ausentes o inválidas.
* Distinguir entre final del directo, chat deshabilitado y error temporal.

# Orden, duplicados y consistencia

Garantizar:

* Orden estable de mensajes.
* Deduplicación mediante ID de YouTube.
* Manejo de eventos recibidos más de una vez.
* Mutaciones aplicadas al mensaje correcto.
* Prevención de mensajes duplicados al reconectar.
* Prevención de duplicados cuando un mensaje cambia de estado.
* Caché de IDs con tamaño y expiración limitados.
* Limpieza de estado al terminar un directo.

Cuando los timestamps de YouTube y el orden de llegada discrepen, conservar el orden operacional del stream sin reordenamientos destructivos.

# Reconexión y errores

Gestionar:

* Errores DNS.
* Timeout de conexión.
* Desconexión.
* HTTP 400.
* HTTP 403.
* HTTP 404.
* HTTP 408.
* HTTP 409 si aparece.
* HTTP 429.
* HTTP 5xx.
* Respuestas vacías.
* JSON inválido.
* HTML inesperado.
* Cambios de versión del cliente Innertube.
* Ausencia de API key.
* Ausencia de continuation.
* Chat deshabilitado.
* Directo terminado.
* Canal eliminado o no disponible.
* Cambios temporales de estructura.

Usar backoff exponencial limitado:

* Sin reintentos simultáneos duplicados.
* Máximo de 30 segundos para errores temporales del chat.
* Respeto de `Retry-After` cuando exista y pueda leerse.
* Reinicio del backoff después de una respuesta válida.
* Retorno posterior a la detección offline cuando el directo termina.

No detener definitivamente un stream por un único error temporal.

# Persistencia

El archivo de estado debe contener únicamente configuración estable:

* Canal.
* Identificador estable.
* Splits asociados.
* Preferencias.
* Versión del esquema.

No persistir:

* API key de Innertube.
* Continuation.
* Payloads del chat.
* Cookies.
* Tokens.
* Contenido de mensajes.
* Historial del chat.

Implementar:

* Escritura a archivo temporal.
* Flush y cierre.
* Sustitución segura del archivo original.
* Copia `.bak`.
* Recuperación desde backup.
* Validación del esquema.
* Migraciones versionadas.
* Recuperación segura desde JSON corrupto.
* Liberación garantizada de `IO_LOCK`.
* Prevención de escrituras concurrentes.
* Escritura solo cuando haya cambios.
* Debounce de escrituras frecuentes.

El plugin solo debe acceder a sus propios archivos.

# Seguridad y privacidad

No incluir:

* OAuth.
* Login.
* Cookies autenticadas.
* Tokens personales.
* Telemetría.
* Analytics.
* Crash reporting externo.
* Backend remoto.
* Servicios de terceros.
* Ejecución de comandos.
* `load`, `loadstring` o evaluación dinámica.
* Descarga de Lua ejecutable.
* Actualización automática.
* Dependencias binarias.
* Node.js.
* npm.
* pnpm.
* Python en runtime.

Las solicitudes de red deben limitarse a hosts oficiales de YouTube estrictamente necesarios.

Documenta todos los hosts.

Valida:

* Esquema HTTPS.
* Host exacto.
* Redirecciones.
* Tamaño máximo razonable de respuestas.
* Tamaño máximo de strings y payloads procesados.
* Longitudes de IDs, nombres y mensajes.
* Datos numéricos.
* URLs de imágenes.
* Colores y formatos recibidos.

No confíes ciegamente en campos suministrados por YouTube.

# Logs

En producción, registrar únicamente:

* Canal.
* Vídeo.
* Estado de conexión.
* Código HTTP.
* Categoría resumida del error.
* Próximo reintento.
* Nombre del renderer desconocido.
* Cambios principales de estado.

No registrar:

* API keys.
* Continuations.
* Respuestas completas.
* HTML completo.
* JSON completo.
* Texto completo de usuarios.
* Datos monetarios innecesarios.
* Identificadores internos que no sean necesarios.

Implementar rate limiting y deduplicación de logs repetidos.

Añadir niveles:

* Error.
* Warning.
* Info.
* Debug.

`Debug` debe estar desactivado por defecto.

# Rendimiento

La release debe demostrar:

* Un polling activo por vídeo.
* Una comprobación offline por canal.
* Distribución a múltiples splits sin nuevas solicitudes.
* Memoria limitada para deduplicación y cachés.
* Limpieza al cerrar splits.
* Limpieza al terminar streams.
* Ausencia de timers huérfanos.
* Ausencia de crecimiento ilimitado de tablas.
* Ausencia de escritura por cada mensaje.
* Ausencia de serialización completa de payloads en producción.

Realiza pruebas con:

* 1 canal.
* 10 canales offline.
* 5 directos activos.
* Un directo representado en varios splits.
* Chat de alta actividad mediante fixtures o simulación.
* Varias horas de ejecución simulada o real cuando sea posible.

# Compatibilidad de Chatterino

Comprueba la versión estable actual de Chatterino y su API de plugins.

Define:

* Versión mínima compatible.
* Sistemas operativos soportados por Chatterino.
* Limitaciones por plataforma.
* Ruta correcta de instalación.
* Estructura exacta del plugin.
* Permisos necesarios.
* Capacidades de mensajes disponibles.
* Soporte de imágenes, links, badges y mutaciones.

No declares una funcionalidad visual como completa sin probar que Chatterino la representa.

Cuando Chatterino no pueda reproducir un detalle visual concreto, conserva toda su semántica mediante texto estructurado. Esto puede considerarse compatibilidad completa de contenido aunque exista una degradación visual documentada.

Ejemplo:

```text
[Super Sticker · 5,00 €] Usuario: sticker “Thanks!”
```

es una degradación visual válida si Chatterino no permite renderizar el sticker, porque conserva el evento, importe, persona y significado.

Omitir el evento no es válido.

# Pruebas automatizadas

Crea un sistema de pruebas reproducible para toda la lógica que pueda separarse de Chatterino.

Usa fixtures anonimizados para cada renderer y acción.

Debe haber pruebas para:

* Todos los renderers soportados.
* Todas las acciones soportadas.
* Todas las continuations.
* Texto.
* Runs mixtos.
* Emotes.
* Badges.
* Super Chats.
* Super Stickers.
* Membresías.
* Regalos.
* Moderación.
* Eliminaciones.
* Mensajes fijados.
* Encuestas.
* Actualizaciones.
* Placeholders.
* Reacciones.
* Redirecciones.
* Eventos de sistema.
* Renderer desconocido.
* Action desconocida.
* JSON inválido.
* Campos ausentes.
* Tipos incorrectos.
* Strings vacíos.
* Strings extremadamente largos.
* IDs duplicados.
* Eventos fuera de orden.
* Mutaciones previas o posteriores al mensaje.
* Backoff.
* Jitter dentro de límites.
* Persistencia.
* Recuperación del backup.
* Migraciones.
* Redacción de logs.
* Limpieza de estado.
* Varias vistas del mismo stream.

No permitas que las pruebas necesiten credenciales personales.

# Pruebas de integración

Añade pruebas o un harness que simule la API de Chatterino para verificar:

* Registro de comandos.
* Creación de mensajes.
* Distribución a splits.
* Cierre de splits.
* Timers.
* Solicitudes.
* Reconexión.
* Mutación o indicación de mensajes eliminados.
* Renderizado de elementos.
* Fallbacks visuales.

# Validación real

Además de los fixtures, valida la versión con chats reales públicos de YouTube que cubran las categorías disponibles.

No guardes ni publiques contenido identificable de usuarios sin anonimizar.

Crea una checklist de validación manual que incluya:

* Canal offline.
* Canal que comienza un directo.
* Directo con chat ordinario.
* Emotes.
* Membresías.
* Super Chats o fixtures equivalentes si no es razonable generar pagos.
* Mensajes fijados.
* Moderación.
* Encuestas.
* Fin del directo.
* Reconexión.
* Reinicio de Chatterino.
* Recuperación del estado.
* Múltiples splits.
* Múltiples canales.

# Fuzzing defensivo

Añade pruebas generativas o fuzzing ligero para parsers:

* Árboles JSON incompletos.
* Propiedades inesperadas.
* Arrays vacíos.
* Valores `null`.
* Tipos incorrectos.
* Profundidad excesiva limitada.
* Strings largas.
* Caracteres Unicode.
* Datos monetarios inesperados.
* Renderers desconocidos.

El parser nunca debe ejecutar código, entrar en bucle infinito ni tumbar todo el plugin por un único evento.

# Criterios de aceptación de 1.0.0

La release solo puede etiquetarse como `1.0.0` si:

1. Todos los renderers y acciones actuales identificados están implementados o representados semánticamente de forma completa.
2. Ningún evento del chat se descarta silenciosamente.
3. Los eventos desconocidos tienen fallback visible y seguro.
4. Los mensajes ordinarios, emotes, badges, pagos, membresías, moderación, fijados, encuestas y eventos de sistema están cubiertos.
5. La reconexión funciona.
6. El polling respeta los intervalos de YouTube.
7. No existen bucles agresivos.
8. No existen solicitudes duplicadas por split.
9. La persistencia es recuperable y atómica dentro de las posibilidades de Lua y Chatterino.
10. Las pruebas automatizadas pasan.
11. La matriz de compatibilidad no contiene entradas obligatorias `Unsupported`.
12. No hay errores críticos o altos abiertos.
13. No hay corrupción conocida de configuración.
14. No hay crecimiento ilimitado de memoria.
15. No hay secretos ni payloads sensibles en logs.
16. La instalación ha sido validada en una versión estable compatible de Chatterino.
17. El paquete de release ha sido instalado desde cero y actualizado desde una configuración anterior.
18. El artefacto coincide con la documentación.
19. El SHA-256 está publicado.
20. El diff completo ha recibido una revisión final de seguridad y regresiones.

Si alguno de estos criterios falla, continúa trabajando hasta resolverlo. No rebajes el alcance y no publiques una versión preliminar bajo el nombre `1.0.0`.

# Repositorio y atribución

Crea en mi cuenta:

```text
chatterino-yt-chat
```

Configuración:

* Público.
* Rama principal `main`.
* Issues habilitadas.
* GitHub Actions habilitado.
* Releases habilitadas.
* Licencia MIT.
* Sin telemetría.
* Sin secrets innecesarios.

Descripción:

```text
A complete, reliable, read-only YouTube Live Chat viewer plugin for Chatterino.
```

Topics:

```text
chatterino
youtube
youtube-chat
youtube-live
lua
plugin
livestream
chat
```

Conserva:

* Copyright original.
* Licencia MIT original.
* Nombre de la autora o autor original.
* Enlace al repositorio original.
* Explicación clara de que este proyecto deriva del plugin original.

Añade una sección `Acknowledgements` y un archivo `NOTICE.md` si ayuda a mantener clara la procedencia.

No presentes todo el trabajo como creación original propia.

# Historial Git

Preserva el historial relevante del subdirectorio `yt-chat` cuando sea razonablemente posible mediante `git filter-repo`, subtree o un método equivalente.

No arrastres el resto de plugins del monorepo.

Si conservar el historial resulta incompatible con la herramienta disponible:

* Importa el código manteniendo atribución.
* Documenta el commit original de procedencia.
* Conserva la licencia.
* Indica el motivo técnico.

# Nombre y metadatos

Nombre del repositorio:

```text
chatterino-yt-chat
```

Nombre visible recomendado:

```text
chatterino-yt-chat
```

Comando:

```text
/yt-chat
```

Versión:

```text
1.0.0
```

Tag:

```text
v1.0.0
```

Título de release:

```text
chatterino-yt-chat 1.0.0
```

No uses etiquetas como:

* alpha
* beta
* rc
* preview
* experimental

solo después de cumplir todos los criterios estables.

# Estructura del repositorio

Como mínimo:

```text
.github/
  workflows/
    ci.yml
    release.yml
  ISSUE_TEMPLATE/
  pull_request_template.md

src/
tests/
fixtures/
scripts/
docs/

README.md
CHANGELOG.md
COMPATIBILITY.md
SECURITY.md
CONTRIBUTING.md
NOTICE.md
LICENSE
info.json
```

Adapta la estructura final a cómo Chatterino carga los plugins. El ZIP de distribución debe contener la estructura que Chatterino espera, no necesariamente toda la estructura del repositorio.

# CI

Crear GitHub Actions para:

* Lint de Lua.
* Tests unitarios.
* Tests de integración simulados.
* Validación de `info.json`.
* Validación de fixtures.
* Comprobación de formato.
* Escaneo básico de secretos.
* Comprobación de que no aparecen hosts de red no permitidos.
* Construcción reproducible del ZIP.
* Generación de SHA-256.
* Comprobación de que la versión y el tag coinciden.
* Publicación de artefactos de CI.
* Creación de release draft para tags válidos.

Fija las acciones de terceros por commit SHA, no únicamente por tags mutables.

Minimiza permisos de `GITHUB_TOKEN`.

No ejecutes código procedente de pull requests no confiables con secretos.

# Documentación

El README debe explicar:

* Qué hace el plugin.
* Que es solo lectura.
* Qué tipos de mensajes soporta.
* Qué hosts utiliza.
* Qué datos persiste.
* Qué no persiste.
* Permisos requeridos.
* Cómo instalarlo.
* Cómo actualizarlo.
* Cómo desinstalarlo.
* Cómo borrar su estado.
* Cómo añadir un vídeo o canal.
* Cómo utilizar varios splits.
* Cómo interpretar eventos degradados visualmente.
* Solución de problemas.
* Versión mínima de Chatterino.
* Limitaciones impuestas por Chatterino.
* Procedencia del proyecto.

`COMPATIBILITY.md` debe contener la matriz completa de acciones y renderers.

`SECURITY.md` debe contener:

* Modelo de amenazas.
* Superficie de red.
* Superficie de filesystem.
* Política de logs.
* Reporte de vulnerabilidades.
* Dependencias.
* Política de actualización.

`CHANGELOG.md` debe documentar `1.0.0` como primera versión estable del proyecto independiente.

# Release

Construye un artefacto reproducible:

```text
chatterino-yt-chat-1.0.0.zip
```

Incluye solo los archivos necesarios para ejecutar el plugin.

Genera:

```text
chatterino-yt-chat-1.0.0.zip.sha256
```

La release debe incluir:

* ZIP.
* SHA-256.
* Notas de release.
* Instrucciones de instalación.
* Compatibilidad.
* Limitaciones visuales de Chatterino, si existen.
* Enlace al proyecto original.
* Licencia.
* Resumen de pruebas.
* Commit exacto de compilación.

Crea la GitHub Release inicialmente como draft.

Después de completar las verificaciones, revisar el artefacto instalado y confirmar todos los criterios de aceptación, publica la release estable `v1.0.0`.

Estás autorizado a:

* Crear el repositorio público `chatterino-yt-chat` en mi cuenta.
* Crear ramas.
* Hacer commits.
* Hacer push.
* Configurar GitHub Actions.
* Crear tags.
* Crear y publicar la release `v1.0.0`.

No estás autorizado a:

* Modificar el repositorio original.
* Abrir pull requests contra el proyecto original.
* Eliminar otros repositorios.
* Forzar pushes.
* Reescribir ramas remotas ya publicadas sin necesidad demostrable.
* Añadir secretos personales.
* Publicar una release que no cumpla los criterios establecidos.

# Flujo de trabajo

1. Inspecciona el proyecto original.
2. Investiga la API actual de Chatterino.
3. Investiga las acciones y renderers actuales de YouTube Live Chat.
4. Crea el repositorio independiente.
5. Preserva el historial relevante o documenta la importación.
6. Diseña la matriz de compatibilidad.
7. Refactoriza la arquitectura.
8. Implementa todos los renderers y acciones.
9. Implementa fallbacks genéricos.
10. Implementa polling, backoff y reconexión.
11. Implementa persistencia segura.
12. Implementa logs seguros.
13. Añade fixtures y pruebas.
14. Ejecuta pruebas y validaciones.
15. Realiza pruebas de larga duración y alta actividad.
16. Audita seguridad, red, memoria y filesystem.
17. Construye el paquete.
18. Instala el ZIP resultante en una instalación limpia de Chatterino.
19. Verifica actualización y recuperación.
20. Revisa la matriz final.
21. Crea el tag `v1.0.0`.
22. Crea y publica la release estable.
23. Entrega un informe final.

# Informe final obligatorio

Al terminar, informa de:

* URL del repositorio.
* URL de la release.
* Commit de `v1.0.0`.
* Archivos principales.
* Arquitectura final.
* Versión mínima de Chatterino.
* Sistemas probados.
* Número de pruebas.
* Resultado de CI.
* Cobertura por renderer y acción.
* Entradas de la matriz de compatibilidad.
* Pruebas reales realizadas.
* Pruebas de carga realizadas.
* Problemas encontrados y corregidos.
* Limitaciones visuales impuestas por Chatterino.
* Riesgos residuales.
* Hosts utilizados.
* Permisos requeridos.
* Tamaño del ZIP.
* SHA-256.
* Confirmación de instalación limpia.
* Confirmación de actualización.
* Confirmación de que no existe telemetría.
* Confirmación de que no se guardan credenciales ni contenido del chat.
* Confirmación de que la release publicada cumple todos los criterios de aceptación de `1.0.0`.

No afirmes que algo fue probado si no se ejecutó realmente. No marques compatibilidad completa basándote únicamente en lectura estática del código.

