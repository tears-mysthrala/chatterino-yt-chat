# Research: Chatterino plugin API (verified 2026-07-19)

Sources (all fetched and inspected directly):

- Latest stable release: **v2.5.5** (2026-03-22) — `gh api repos/Chatterino/chatterino2/releases/latest`
- `src/controllers/plugins/LuaAPI.hpp` @ v2.5.5
- `src/controllers/plugins/api/{ChannelRef,Message,HTTPRequest,HTTPResponse}.hpp` @ v2.5.5 and @ master
- `src/controllers/plugins/PluginController.cpp` @ v2.5.5 (`openLibrariesFor`)
- `docs/wip-plugins.md` @ v2.5.5
- `docs/plugin-info.schema.json`

## Plugin structure and loading

- Plugins live in `<appdata>/Plugins/<plugin_name>/` next to `Settings`/`Logs`.
  - Windows: `%APPDATA%\Chatterino2\Plugins\`
  - macOS: `~/Library/Application Support/chatterino/Plugins/`
  - Linux: `~/.local/share/chatterino/Plugins/`
- Entry point: `init.lua` + `info.json`; arbitrary data in `data/`.
- `require("a.b")` resolves relative to current file, then plugin dir;
  dynamic-library searcher removed; binary chunks never loaded; `data/`
  files are not loadable.
- `info.json` version **must** be semver 2.0. No auto-update mechanism
  exists in Chatterino.

## Lua sandbox (v2.5.5, `PluginController.cpp` lines 139–240)

Loaded: base (`_G`), coroutine, table, string, math, utf8, package
(restricted), `io` (restricted), `debug.traceback` only.

**NOT loaded: `os`** (`LUA_OSLIBNAME` is commented out — no `os.time`,
`os.clock`, `os.remove`, `os.rename`, `os.getenv`, `os.exit`).

- `load`: only in debug builds (release builds: unavailable).
- `loadfile`, `dofile`: removed.
- `print(...)`: equivalent to `c2.log(c2.LogLevel.Debug, ...)`.
- `io`: no stdin/stdout/stderr; `io.open` requires the matching
  FilesystemRead/Write permission and the path must be inside the
  plugin's data directory; `io.popen` and `io.tmpfile` unavailable.
- Built-in JSON module: `require("chatterino.json")` (parse/stringify).

Consequences implemented in this project:

- Monotonic clock via `c2.later` heartbeat (`src/support/clock.lua`).
- Persistence without `os.rename` (`src/state/persistence.lua`, ADR-004).

## Permissions (info.json)

- `Network` — HTTP requests (and image loading on master).
- `FilesystemRead` / `FilesystemWrite` — limited to the plugin data dir.

## c2 API (v2.5.5)

- `c2.register_command(name, handler)`, `c2.register_callback(...)`,
  `c2.log(level, ...)`, `c2.later(cb, ms)`.
- `c2.HTTPRequest.create(method, url)`: `on_success/on_error/finally`,
  `set_timeout`, `set_payload`, `set_header`, `execute`.
- `c2.HTTPResponse`: `data()`, `status()`, `error()` — **no response
  headers** (so `Retry-After` is unreadable today; parser kept for the
  future).
- `c2.Channel`: `by_name`, `get_name`, `add_message`,
  `add_system_message`, `send_message`, **message mutation**:
  `find_message_by_id(id)`, `replace_message(msg, replacement)`,
  `replace_message_at(index, replacement)`, `message_snapshot(n)`,
  `last_message`, `clear_messages`, `count_messages`,
  `on_display_name_changed`, `on_messages_cleared`, `on_message_replaced`.
- `c2.Message.new(init)`: `id`, `flags`, `message_text`, `search_text`,
  `login_name`, `display_name`, `username_color`, `highlight_color`,
  `elements`.

## Message elements

- v2.5.5 `MessageElementInit`: `text`, `single-line-text`, `mention`,
  `timestamp`, `twitch-moderation`, `linebreak`, `reply-curve`.
  **No image elements constructible.**
- `master` (post-2.5.5, unreleased at research date) adds `c2.Image`,
  `c2.ImageSet`, and `image`/`circular-image`/`scaling-image` elements,
  plus per-element `link` actions.

## Minimum version decision

Plugin requires the 2.5.x API (`find_message_by_id` for in-place
moderation markers). Minimum supported: **Chatterino 2.5.0**
(2.5.5 verified). Older versions work in degraded mode only and are not
supported for 1.0.0.

## Platform support

Chatterino ships stable binaries for Windows, macOS and Linux. No
platform-specific plugin API differences are documented; `io` path
handling uses the plugin data dir transparently.
