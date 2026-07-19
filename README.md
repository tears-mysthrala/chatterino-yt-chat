# chatterino-yt-chat

A complete, reliable, **read-only** YouTube Live Chat viewer plugin for Chatterino.

## Status

- Stable target: `1.0.0`
- Command: `/yt-chat <youtube-url>`
- Scope: read-only visualization of YouTube Live Chat events in Chatterino

## Read-only guarantee

This plugin does **not** send chat messages, moderate users, authenticate accounts, execute remote code, or upload telemetry.

## Supported message/event families

- Regular text messages (runs, links, Unicode emoji, YouTube emoji/custom emoji fallback)
- Super Chat / Super Sticker
- Membership events (including gifted flows when present in payload)
- Moderation-visible mutations (delete/hide/remove markers)
- Pin/banner operations
- Poll updates
- Placeholder/system/unknown events with safe fallback

See full action/renderer matrix in [`COMPATIBILITY.md`](COMPATIBILITY.md).

## Allowed network hosts

Only HTTPS requests to:

- `www.youtube.com`
- `youtube.com`
- `m.youtube.com`
- `youtu.be`

## Persisted data

Stored in `YT_CHAT.json`:

- configured channels/handles
- split bindings
- schema version
- plugin settings

Never persisted:

- API keys
- continuations
- cookies/tokens
- chat payloads
- chat history

## Installation

1. Download `chatterino-yt-chat-1.0.0.zip` from release assets.
2. Extract plugin files into Chatterino plugin directory.
3. Ensure `init.lua`, `info.json`, `src/`, `libs/` are present.
4. Restart Chatterino.

## Update

1. Close Chatterino.
2. Replace plugin files with new release ZIP.
3. Keep `YT_CHAT.json` to preserve bindings.
4. Start Chatterino and verify `/yt-chat` works.

## Uninstall

1. Close Chatterino.
2. Remove plugin directory.
3. Remove `YT_CHAT.json` and `YT_CHAT.json.bak` if desired.

## Usage

- Add active stream URL:
  - `https://www.youtube.com/watch?v=<id>`
  - `https://youtu.be/<id>`
  - `https://www.youtube.com/live/<id>`
- Add channel for offline-to-live detection:
  - `https://www.youtube.com/channel/<id>`
  - `https://www.youtube.com/@handle`
  - `/live` variants

The same stream can fan out to multiple Chatterino splits without duplicated polling per split.

## Visual degradations

When Chatterino cannot render an image/sticker/badge with native visuals, semantic text fallback is emitted (for example `[Super Sticker · €2.00] user`).

## Troubleshooting

- Invalid URL: only HTTPS YouTube hosts are accepted.
- No continuation: channel may be offline or chat disabled.
- Repeated HTTP errors: plugin retries with bounded backoff.

## Compatibility

- Minimum Chatterino: stable branch with plugin API supporting `HTTPRequest`, `register_command`, `Message.new`, and timers.
- OS support follows Chatterino official binaries (Windows/macOS/Linux).

## Project origin

This project is derived from the original `yt-chat` plugin in:

`https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat`

Original license and attribution are preserved (MIT). See [`NOTICE.md`](NOTICE.md) and [`LICENSE`](LICENSE).
