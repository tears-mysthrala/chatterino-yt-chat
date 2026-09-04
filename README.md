# chatterino-yt-chat

A complete, reliable, **read-only** YouTube Live Chat viewer plugin for Chatterino.

This project derives from the original [`yt-chat`](https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat)
plugin by **kararty** (MIT). See [NOTICE.md](NOTICE.md) and [LICENSE](LICENSE).

> **Unofficial project.** `chatterino-yt-chat` is a community plugin. It is
> **not** affiliated with, endorsed by, or supported by the Chatterino
> project, YouTube, or Google. "Chatterino" and "YouTube" are trademarks of
> their respective owners. It relies on undocumented YouTube internals
> (Innertube) that may change or break at any time without notice.

## What it does

`chatterino-yt-chat` turns Chatterino into a persistent viewer for the chat
of YouTube live streams. Moderators write and moderate from YouTube Studio;
this plugin lets the person watching the chat stay inside Chatterino and see
everything that happens, across as many splits as they want.

- **Read-only**: it never sends messages, never moderates, never logs in.
- **Complete**: ordinary messages, Super Chats, Super Stickers, memberships,
  gift memberships, polls, pinned messages, moderation events, mode changes,
  tickers, placeholders/reactions and unknown future events all get a visible
  representation. See the full matrix in [COMPATIBILITY.md](COMPATIBILITY.md).
- **Polite**: polling intervals come from YouTube itself
  (`timeoutMs` in continuations), with defensive clamps — no aggressive
  fixed-rate loops.
- **Persistent**: channels you add survive restarts; offline channels are
  watched until a stream starts (backoff 30/60/120/300 s).
- **OBS-ready**: when
  [chatterino-multichat-overlay](https://github.com/tears-mysthrala/chatterino-multichat-overlay)
  is running, events are copied to its loopback-only browser source. Overlay
  failures never interrupt normal Chatterino delivery.

## Requirements

- **Chatterino 2.5.x or newer** (built with plugin support; tested against
  the v2.5.5 plugin API).
- Platforms: same as Chatterino (Windows, macOS, Linux).
- Plugin permissions requested in `info.json`: `Network`, `FilesystemRead`,
  `FilesystemWrite` (the latter two are limited by Chatterino to the
  plugin's own data directory).

## Authentication and scopes

There is **no authentication**: no login, no OAuth flow, no user
credentials, no YouTube API key to configure, and no Google account
scopes are requested. The plugin works exactly like an anonymous web
browser visiting the stream page:

1. It fetches the public watch/`/live` page over HTTPS.
2. It extracts the public `INNERTUBE_API_KEY` and client version embedded
   in that page (the same values every visitor's browser receives).
3. It polls `youtubei/v1/live_chat/get_live_chat` with a continuation
   token — a read-only endpoint. There is no code path that sends chat
   messages, moderates, subscribes, or likes.

The Innertube key and continuation tokens are held in memory only and are
never written to disk or logs (see [Persisted data](#persisted-data)).

## Installation

### Windows (double-click installer)

1. Open the [Releases page](https://github.com/tears-mysthrala/chatterino-yt-chat/releases)
   and select the latest release that is not marked **Pre-release**.
2. Under **Assets**, download the file whose name starts with
   `chatterino-yt-chat-` and ends in `.zip`, plus its matching `.sha256` file.
   Do not download the files named **Source code**.
3. Before extracting anything, complete the **Required download verification**
   below. Stop if the hashes do not match.
4. Right-click the verified ZIP, select **Extract all**, and open the extracted folder.
   Do not run the installer from inside the ZIP preview.
5. Double-click `install-or-update.cmd`. Do not run it as administrator.
6. Wait for `Done`, press any key to close the installer, and open Chatterino.
7. In the input box of a named channel panel, enter `/yt-chat` to confirm that
   the plugin responds with its help.

The installer closes Chatterino normally if needed, backs up the previous
plugin and its settings under `%APPDATA%\Chatterino2\PluginBackups`, preserves
`data/`, removes obsolete program files, and enables the plugin automatically.
It uses the Windows PowerShell already installed with Windows, without changing
the system-wide execution policy. No YouTube login, API key, administrator
access, or extra software is required.

If the launcher does not open, right-click an empty area in the extracted
folder, select **Open in Terminal**, and run:

```powershell
& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1 -CloseChatterino
```

### macOS and Linux

Extract the contents of the release ZIP into a folder named
`chatterino-yt-chat` inside Chatterino's `Plugins` directory:

- **macOS**: `~/Library/Application Support/chatterino/Plugins/`
- **Linux**: `~/.local/share/chatterino/Plugins/`
- **Linux (Flatpak)**: `~/.var/app/com.chatterino.chatterino/data/chatterino/Plugins/`

After extraction, `init.lua` and `info.json` must be directly inside that
folder. Restart Chatterino, open **Settings → Plugins**, turn on
**Enable plugins**, and enable `chatterino-yt-chat`.

### Required download verification

The release provides a `.sha256` file with the expected SHA-256 fingerprint.
Verify it before extracting or running the ZIP. On Windows, open PowerShell, type `Get-FileHash `
(including the final space), drag the downloaded ZIP into the PowerShell
window, type ` -Algorithm SHA256`, and press Enter. The displayed **Hash** must
match the sequence in the `.sha256` file; uppercase and lowercase do not
matter. This command only reads the file.

## Updating

Download and extract the new release, then double-click
`install-or-update.cmd` again. The same installer handles clean installs and
updates. It preserves and verifies `data/`, creates a recoverable backup, and
updates the existing plugin without manual file copying. Open Chatterino and
enter `/yt-chat status` in a named channel panel.

Configuration in `data/YT_CHAT.json` is migrated automatically. The plugin
also maintains a `.bak` recovery copy; the installer backup protects the whole
previous plugin directory and Chatterino settings.

## Uninstalling / deleting state

- Remove the plugin directory `Plugins/chatterino-yt-chat/`.
- To also delete its state, remove `data/YT_CHAT.json`,
  `data/YT_CHAT.json.bak`, `data/YT_CHAT.json.tmp` and any explicitly created
  `data/YT_CHAT.export.json*` or `data/YT_CHAT.diagnostics.json*` files inside
  that directory.
- The plugin never writes outside its own data directory.

## Usage

In any Chatterino split (it must be a named channel split):

```text
/yt-chat <YouTube URL>
```

Operational commands:

```text
/yt-chat list
/yt-chat status
/yt-chat health [export]
/yt-chat @handle
/yt-chat auto [@handle]
/yt-chat pause <channel>
/yt-chat resume <channel>
/yt-chat remove <channel>
/yt-chat delay [0-30000]
/yt-chat lang [es|en]
/yt-chat config
/yt-chat export
/yt-chat import
```

Command names are international and stay the same in every interface language.
Legacy Spanish aliases remain accepted for backward compatibility but are no
longer shown in help or completion.

Accepted inputs (URLs are normalized automatically and restricted to HTTPS on official hosts):

- `@handle` (short form; binds it to the current conversation)
- `https://www.youtube.com/watch?v=<id>` (extra params are fine)
- `https://youtu.be/<id>`
- `https://www.youtube.com/live/<id>`
- `https://www.youtube.com/shorts/<id>`
- `https://www.youtube.com/channel/<id>` (and `/live`)
- `https://www.youtube.com/@handle` (and `/live`)
- `https://www.youtube.com/c/<name>` / `/user/<name>` (and `/live`)

Behavior:

- **Live stream**: chat connects immediately.
- **Offline channel**: the channel is stored and checked periodically
  (30 s → 60 s → 120 s → 300 s backoff); when a stream starts, the chat
  connects automatically.
- **Persistent automatic connection**: `/yt-chat auto` uses the current
  conversation name as the YouTube handle; `/yt-chat auto @handle` overrides
  it explicitly. The binding is stored; after restarting Chatterino it resumes
  monitoring and connects when live.
- **Multiple splits**: run `/yt-chat` with the same channel in several
  splits — the plugin polls once per stream and distributes messages to
  every bound split. Closing all splits stops polling for that stream.
- **Multiple channels**: repeat per channel. Each channel gets one offline
  check regardless of how many splits show it.

## How events look

The Chatterino 2.5.x plugin API renders text elements only, so everything
image-based is represented textually (semantics preserved):

```text
▶️ YT 12:00 (SomeChannel) [MOD] Moderator Jane: hello chat 😀
▶️ YT 12:01 [Super Chat · €5.00] Generous Viewer: keep it up 🎉
▶️ YT 12:02 [Super Sticker · $2.00] Viewer One: sticker “Thanks!”
▶️ YT 12:03 [New member · Gold] Viewer Two: Welcome!
▶️ YT 12:04 [Gift ×5] Generous Gifter gifted 5 memberships
▶️ YT 12:05 [Poll] Best option? Option A (73%) · Option B (26%)
▶️ YT 🗑 Message deleted (id: …)
▶️ YT 📌 Pinned by Channel Owner — Viewer One: announcement
▶️ YT ⚙ Slow mode is on — Send a message every 10 seconds
▶️ YT ⚠ Unsupported event: liveChatFutureRenderer2042 — …
```

See [COMPATIBILITY.md](COMPATIBILITY.md) for the exact representation of
every action/renderer and the documented visual degradations.

## Network surface

Only HTTPS requests to official YouTube hosts, needed for operation:

| Host | Purpose |
| --- | --- |
| `www.youtube.com` | watch/`/live` pages, `youtubei/v1/live_chat/get_live_chat` |
| `youtube.com`, `m.youtube.com`, `youtu.be` | accepted input URL forms (normalized to `www.youtube.com`) |

No redirects to other hosts are followed by the plugin itself; URLs are
validated before every request. No third-party services, no analytics,
no telemetry, no auto-update.

## Rate limiting and error handling

The plugin is deliberately polite towards YouTube:

- **Chat polling** intervals are dictated by YouTube itself (`timeoutMs`
  in each continuation response), clamped to 500–15000 ms with a 1000 ms
  fallback when YouTube does not provide one (configurable, see
  [Settings](#settings)). One poller per stream, no matter how many
  splits display it.
- **Offline channel checks** back off 30 → 60 → 120 → 300 s (plus small
  jitter) and stay at 300 s until a stream starts.
- **Transient errors** (network failures, empty/oversize/invalid
  responses, non-fatal HTTP statuses) retry with exponential backoff
  capped at 30 s, honoring `Retry-After` when present.
- **Fatal conditions** (HTTP 400/403/404, chat disabled, stream ended)
  stop polling and return the channel to offline watch automatically —
  it reconnects on its own if the stream comes back.

## Persisted data

Stored only in the plugin data directory (`data/YT_CHAT.json`):

- configured channels (stable channel id and/or handle, display name)
- split bindings
- plugin settings (debug flag, polling limits)
- schema version

**Never** persisted: Innertube API keys, continuation tokens, cookies,
chat payloads, message contents, chat history.

`/yt-chat export` creates `data/YT_CHAT.export.json` with the same validated,
non-sensitive configuration schema. `/yt-chat import` only reads that fixed
path and revalidates the complete snapshot before applying it.

`/yt-chat health export` creates `data/YT_CHAT.diagnostics.json`. It contains
only version/capability data, aggregate counters and stream timing/state; it
never includes API keys, continuations, message text or response payloads.

Writes are atomic within what the Chatterino Lua sandbox allows
(temp file + verify + write + `.bak` recovery copy), debounced, and only
happen when something actually changed.

## Settings

`data/YT_CHAT.json → settings` (edit with Chatterino closed):

```json
{
  "debug": false,
  "offline_poll_schedule": [30, 60, 120, 300],
  "offline_poll_max": 300,
  "chat_poll_min_ms": 500,
  "chat_poll_max_ms": 15000,
  "chat_poll_fallback_ms": 1000,
  "chat_sync_delay_ms": 0,
  "language": "es"
}
```

- `debug`: enables verbose logging and anonymized samples of unknown
  renderers (written through the diagnostic sample sink; off by default).
- `offline_poll_schedule` / `offline_poll_max`: offline check backoff
  (seconds). Keep values within 15–900 s.
- `chat_poll_*`: clamps applied to YouTube-provided polling intervals.
- `chat_sync_delay_ms`: presentation delay applied to normalized event batches
  without slowing YouTube polling (`0`–`30000` ms). Change it live with
  `/yt-chat delay <ms>`; run `/yt-chat delay` to inspect the current value.
  Chatterino 2.5.5 uses a 100 ms monotonic heartbeat, so delivery targets that
  value with up to one heartbeat of scheduler granularity.
- `language`: operational UI language; accepts only `"es"` or `"en"` and can
  be changed live with `/yt-chat lang <es|en>`.

Chatterino 2.5.5 does not expose a plugin API for adding controls to its
Settings GUI. `/yt-chat config` therefore reports the effective configuration,
while the settings model remains isolated so a future stable GUI API can be
wired in without changing persisted data. Command completion is registered
when supported by Chatterino.

## Troubleshooting

- **"URL no válida"**: only HTTPS URLs on official YouTube hosts are
  accepted; redirects to other domains are not followed.
- **Offline channel never connects**: the channel may not have a `/live`
  tab or the handle changed; re-add it with the canonical `/channel/<id>`
  URL. Checks back off up to 5 minutes — be patient after many failures.
- **Chat stops mid-stream**: the plugin detects stream end, chat disabled
  and fatal HTTP errors (400/403/404) and returns the channel to offline
  watch automatically. Temporary errors retry with backoff (max 30 s).
- **Duplicate channel entries**: the plugin merges bindings that resolve
  to the same stable channel id, even if added via different URL forms.
- **Logs**: Chatterino log contains `[yt-chat]` lines; set `debug: true`
  for diagnostics. Logs never contain API keys, continuations or full
  payloads.

## Security & privacy

See [SECURITY.md](SECURITY.md). In short: read-only, no credentials, no
remote code execution (`load`/`loadstring` are never used), no telemetry,
strict input validation of every field coming from YouTube.

## Development

- Tests: `scripts/test.sh` (unit + integration harness + fuzz + load;
  plain Lua, no Chatterino needed).
- Build: `scripts/build_release.sh 1.3.0` → reproducible ZIP +
  `scripts/sha256.sh` for the checksum.
- Architecture and internal contracts: `docs/architecture.md`.
- Research notes: `docs/research/`.

## Project origin and acknowledgements

This repository is an independent continuation of the experimental
[`yt-chat`](https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat)
plugin from the `Remahy/Chatterino-Plugins` monorepo, created by
**kararty** under the MIT license. The relevant git history was preserved
via subtree split. See [NOTICE.md](NOTICE.md).

Continuation regexes credit: [Agash/YTLiveChat](https://github.com/Agash/YTLiveChat).
Renderer/action field research: [chat-downloader](https://github.com/xenova/chat-downloader),
[masterchat](https://github.com/sigvt/masterchat),
[pytchat](https://github.com/taizan-hokuto/pytchat).
