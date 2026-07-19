# chatterino-yt-chat

A complete, reliable, **read-only** YouTube Live Chat viewer plugin for Chatterino.

This project derives from the original [`yt-chat`](https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat)
plugin by **kararty** (MIT). See [NOTICE.md](NOTICE.md) and [LICENSE](LICENSE).

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

## Requirements

- **Chatterino 2.5.x or newer** (built with plugin support; tested against
  the v2.5.5 plugin API).
- Platforms: same as Chatterino (Windows, macOS, Linux).
- Plugin permissions requested in `info.json`: `Network`, `FilesystemRead`,
  `FilesystemWrite` (the latter two are limited by Chatterino to the
  plugin's own data directory).

## Installation

1. Download `chatterino-yt-chat-1.0.0.zip` from the
   [latest release](https://github.com/tears-mysthrala/chatterino-yt-chat/releases)
   and verify it against the published `.sha256`.
2. Open Chatterino's plugin directory:
   - **Windows**: `%APPDATA%\Chatterino2\Plugins\`
   - **macOS**: `~/Library/Application Support/chatterino/Plugins/`
   - **Linux**: `~/.local/share/chatterino/Plugins/`
3. Extract the ZIP so you get `Plugins/chatterino-yt-chat/` containing
   `init.lua`, `info.json`, `src/`, `libs/` (and the docs).
4. Restart Chatterino and enable the plugin if prompted
   (Settings → Plugins).

## Updating

1. Close Chatterino (or disable the plugin).
2. Replace the plugin directory contents with the new ZIP.
3. Your configuration in `data/YT_CHAT.json` is preserved and migrated
   automatically (schema migrations are versioned; a `.bak` copy is kept).
4. Restart and check `/yt-chat` still works.

## Uninstalling / deleting state

- Remove the plugin directory `Plugins/chatterino-yt-chat/`.
- To also delete its state, remove `data/YT_CHAT.json`,
  `data/YT_CHAT.json.bak` and `data/YT_CHAT.json.tmp` inside that directory.
- The plugin never writes outside its own data directory.

## Usage

In any Chatterino split (it must be a named channel split):

```text
/yt-chat <YouTube URL>
```

Accepted URL forms (normalized automatically, HTTPS only):

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
- **Multiple splits**: run `/yt-chat` with the same channel in several
  splits — the plugin polls once per stream and distributes messages to
  every bound split. Closing all splits stops polling for that stream.
- **Multiple channels**: repeat per channel. Each channel gets one offline
  check regardless of how many splits show it.

## How events look

The Chatterino 2.5.x plugin API renders text elements only, so everything
image-based is represented textually (semantics preserved):

```text
[YT] 12:00 (SomeChannel) [MOD] Moderator Jane: hello chat 😀
[YT] 12:01 [Super Chat · €5.00] Generous Viewer: keep it up 🎉
[YT] 12:02 [Super Sticker · $2.00] Viewer One: sticker “Thanks!”
[YT] 12:03 [New member · Gold] Viewer Two: Welcome!
[YT] 12:04 [Gift ×5] Generous Gifter gifted 5 memberships
[YT] 12:05 [Poll] Best option? Option A (73%) · Option B (26%)
[yt-chat] 🗑 Message deleted (id: …)
[yt-chat] 📌 Pinned by Channel Owner — Viewer One: announcement
[yt-chat] ⚙ Slow mode is on — Send a message every 10 seconds
[yt-chat] ⚠ Unsupported event: liveChatFutureRenderer2042 — …
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

## Persisted data

Stored only in the plugin data directory (`data/YT_CHAT.json`):

- configured channels (stable channel id and/or handle, display name)
- split bindings
- plugin settings (debug flag, polling limits)
- schema version

**Never** persisted: Innertube API keys, continuation tokens, cookies,
chat payloads, message contents, chat history.

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
  "chat_poll_fallback_ms": 1000
}
```

- `debug`: enables verbose logging and anonymized samples of unknown
  renderers (written through the diagnostic sample sink; off by default).
- `offline_poll_schedule` / `offline_poll_max`: offline check backoff
  (seconds). Keep values within 15–900 s.
- `chat_poll_*`: clamps applied to YouTube-provided polling intervals.

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
- Build: `scripts/build_release.sh 1.0.0` → reproducible ZIP +
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
