# Security Policy

## Threat model

`chatterino-yt-chat` is a local, read-only plugin that displays public
YouTube Live Chat inside Chatterino. Assets an attacker might target:

- the Chatterino process (via hostile or malformed YouTube payloads)
- the plugin's state file (via corruption or hostile writes)
- the user's network footprint (via unexpected outbound requests)
- user privacy (via logs or persisted content)

Adversaries considered: malicious or compromised chat content, hostile
URLs pasted by the user, tampered HTTP responses, future unknown
renderers/actions introduced by YouTube.

## What the plugin never does

- No OAuth, no login, no cookies, no personal tokens.
- No telemetry, analytics, crash reporting or remote backends.
- No `load`, `loadstring`, `dofile` or dynamic code evaluation.
- No downloads of executable code; no auto-update mechanism.
- No shell/command execution (`io.popen` unused and unavailable).
- No chat writes or moderation actions (read-only scope).

## Network surface

HTTPS only, strict allowlist checked before every request:

- `www.youtube.com` (watch pages, `/live` pages, Innertube `get_live_chat`)
- Input URLs on `youtube.com`, `m.youtube.com`, `youtu.be` are normalized
  to `www.youtube.com` before any request.

Redirect-unwrapping for chat links never issues requests. Image URLs found
in payloads (emotes, stickers, avatars) are validated against a separate
image-host allowlist (`yt3/yt4.ggpht.com`, `i.ytimg.com`,
`lh3.googleusercontent.com`, `fonts.gstatic.com`) but are **not fetched**
by the current Chatterino plugin API — they are shown as text.

Response limits: chat responses capped at 4 MiB, watch pages at 8 MiB.
Strings, ids, runs and URLs are length-capped before use
(`src/support/validation.lua`).

## Filesystem surface

The plugin reads/writes only inside its own Chatterino plugin data
directory (enforced by Chatterino's `FilesystemRead`/`FilesystemWrite`
permissions):

- `YT_CHAT.json` — state
- `YT_CHAT.json.bak` — last-known-good backup
- `YT_CHAT.json.tmp` — staging file during writes

Write protocol: temp file → flush → verify → backup current → write →
verify → restore-from-backup on failure. The Chatterino Lua sandbox has
no `os.rename`, so rename-atomic replace is impossible there; this
tmp+verify+bak protocol is the strongest available, and any interruption
leaves a recoverable `.bak`. On platforms where `os.rename` exists it is
used.

## Logging policy

Production logs contain only: channel/video identifiers, connection state,
HTTP status, error category, next retry, unknown renderer names, major
state changes. Never logged: API keys, continuations, cookies, full
responses, full HTML/JSON, full user message text, monetary payloads.

- Levels: error, warning, info, debug (debug **off** by default).
- Rate limiting and repeat-deduplication bound log volume.
- Debug mode can emit anonymized unknown-renderer samples through a
  redaction filter (continuation/cookie/token/key/authorization/secret
  fields stripped recursively).

## Input validation

Every field from YouTube is treated as hostile: type-checked, length
capped, ids charset-filtered, colors range-checked, URLs scheme+host
validated. Unknown renderers/actions go through a defensive fallback that
extracts only recognizable fields and never executes anything.

## Dependencies

- Chatterino's embedded Lua 5.4 runtime (sandboxed: no `os` library,
  restricted `io`, no native module loading).
- Bundled `libs/json.lua` (vendored, MIT, rxi/json.lua).
- No Node.js, npm, pnpm, Python or binary dependencies at runtime.

## Vulnerability reporting

Report vulnerabilities privately via GitHub Security Advisories on this
repository. Do not include exploit payloads or other users' chat content
in reports. We aim to acknowledge within 7 days.

## Update policy

- Stable releases are tagged `vX.Y.Z` with SHA-256 checksums for every
  artifact. Verify the ZIP against the published checksum before
  installing.
- Security fixes ship as patch releases with a changelog entry.
- There is intentionally **no** auto-update: updates are always a manual,
  verifiable action by the user.
