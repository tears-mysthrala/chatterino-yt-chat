# Validation: installation in stable Chatterino (2026-07-19)

Environment: Arch Linux x86_64, official `Chatterino-Ubuntu-24.04.deb`
**v2.5.5** (SHA-256 verified against `sha256-checksums.txt`:
`8ad1ec90…da48ce`), extracted locally (no system install), run headless
with `QT_QPA_PLATFORM=minimal`, sandboxed app data via `XDG_DATA_HOME`,
local Ubuntu ICU 74 libs. Network access to `www.youtube.com` available.

## Evidence captured

### 1. Clean install from the release ZIP

- `dist/chatterino-yt-chat-1.0.0.zip` extracted to
  `Plugins/chatterino-yt-chat/` → structure accepted (`init.lua` +
  `info.json` found by the loader).
- Plugin enabled via `/plugins/supportEnabled` +
  `/plugins/enabledPlugins=["chatterino-yt-chat"]`.

Loader log:

```text
chatterino.lua: Loading plugins in "<appdata>/Plugins"
chatterino.lua: Found init.lua, now looking for info.json!
chatterino.lua: Running lua file: <appdata>/Plugins/chatterino-yt-chat/init.lua
chatterino.lua: [yt-chat][info] plugin_loaded | channels=0
```

### 2. End-to-end with a real public live chat

State seeded with the Lofi Girl channel (`UCSJ4gkVC6NrvII8umztf0Ow`,
split `ytchat-e2e` created via `window-layout.json`). Within seconds:

```text
[yt-chat][info] plugin_loaded | channels=1
[yt-chat][info] chat_started | channel=Lofi Girl video=VAlMDl00mYY
[yt-chat][info] stream_went_live | channel=UCSJ4gkVC6NrvII8umztf0Ow video=VAlMDl00mYY
```

- The offline monitor fetched `/live`, parsed metadata, found the
  continuation and started polling `get_live_chat` — all from inside
  Chatterino, no credentials.
- Chatterino's own channel logging (enabled for the test) recorded real
  chat messages delivered by the plugin into the split
  (`Logs/Twitch/Channels/ytchat-e2e/…log`): author names, Unicode emoji
  rendered natively, custom emotes shown as `:shortcut:` text (documented
  degradation). Real usernames are kept only in the local sandbox; they
  are not committed or published.

### 3. Upgrade / migration path

- Legacy state file (original plugin shape, no `schema_version`) loads
  cleanly: migration applies in memory, channels work, chat starts.
  The file is rewritten in the new schema on the next configuration
  change (write-on-change policy).
- Corruption recovery covered by unit tests (`persistence_spec`: main
  corrupt → `.bak` recovery; both corrupt → defaults).

### 4. Sandbox conformance observed

- Plugin opened files only inside its data directory (loader logs the
  `io.open` calls: `data/YT_CHAT.json`, `data/YT_CHAT.json.bak`).
- No `os` library available — clock heartbeat fallback worked (3 plugin
  timers alive: heartbeat, offline monitor, chat poll).
- Logs route through `c2.log` into Chatterino's log system.

## What was NOT validated in-app

- Interactive `/yt-chat` command entry (requires GUI input; covered by
  the integration harness `tests/integration/`).
- Visual rendering quality of the split UI (headless environment).
  Message delivery to the channel was verified via Chatterino's channel
  log, not via screenshots.
- Multi-hour soak in-app (3-hour simulated soak is covered in
  `tests/perf/load_spec.lua`).
