## chatterino-yt-chat 1.0.0

First stable release of **chatterino-yt-chat**: a complete, reliable,
**read-only** YouTube Live Chat viewer plugin for Chatterino.

Derived from the experimental [`yt-chat`](https://github.com/Remahy/Chatterino-Plugins/tree/main/yt-chat)
plugin by **kararty** (MIT). History preserved via subtree split; see
NOTICE.md. License: MIT.

### Assets

- `chatterino-yt-chat-1.0.0.zip` — install package (33 files)
- `chatterino-yt-chat-1.0.0.zip.sha256` — checksum
- SHA-256: `472e5fe6906ce1be2f43a46f9db915f566c2c79c4c47f55d64fe685828c83318`
- Build: reproducible (double-build hash check in CI), built by CI from the
  tagged commit (see this release's tag).

### Installation

1. Download the ZIP and verify: `sha256sum -c chatterino-yt-chat-1.0.0.zip.sha256`
2. Extract into Chatterino's plugin directory:
   - Windows: `%APPDATA%\Chatterino2\Plugins\chatterino-yt-chat\`
   - macOS: `~/Library/Application Support/chatterino/Plugins/chatterino-yt-chat/`
   - Linux: `~/.local/share/chatterino/Plugins/chatterino-yt-chat/`
3. Restart Chatterino, enable the plugin, and in any split run:
   `/yt-chat https://www.youtube.com/@channel/live`

### Compatibility

- Chatterino **2.5.x** (verified against the official v2.5.5 build).
- Windows / macOS / Linux.
- Permissions: Network, FilesystemRead, FilesystemWrite (limited to the
  plugin's own data directory).

### Coverage

All currently documented YouTube Live Chat actions/renderers are
represented: ordinary messages (runs, Unicode emoji, custom emotes, links,
badges/roles), Super Chat, Super Sticker, memberships (new/milestone/
gifts/receptions), moderation (in-place deletion/replacement via message
ids), pinned banners, polls (open/update/close/results), tickers, mode
changes, engagement notices, placeholders/reactions (coalesced) and a
visible safe fallback for unknown events. Full matrix: COMPATIBILITY.md.

### Documented visual degradations (Chatterino 2.5.x plugin API)

- Remote images (custom emotes, stickers, avatars, badge icons) render as
  text (`:shortcut:`, alt text, `[MOD|MEMBER·Nm]` tags); Unicode emoji are
  native.
- Links render as link-colored text (URL preserved).
- Super Chat tier colors apply to message highlight; poll bars and ticker
  visuals render as structured text.

### Verification summary

- Automated suite: **1301 assertions** (unit + integration harness with
  mocked Chatterino + defensive fuzzing + load scenarios: 5 streams,
  10 offline channels, multi-split fan-out, 3 h simulated runtime) — green
  in CI.
- Fixtures: anonymized real `get_live_chat` captures + structure-verified
  synthetic fixtures for every supported action/renderer.
- Real validation: installed from this ZIP in the official Chatterino
  2.5.5 build; plugin loaded and received a real public live chat
  end-to-end (offline detection → polling → message delivery to a split);
  legacy state migration verified. Details: `docs/validation/`.
- CI: lint (luacheck, 0 warnings), format check, fixture validation,
  host allowlist check, secret scan, reproducible build, SHA-256.

### Privacy

Read-only: no login, no cookies, no telemetry, no remote backends, no
auto-update. Only HTTPS to official YouTube hosts. Persists only channel
configuration — never API keys, continuations, payloads or chat content.
