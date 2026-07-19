# Security Policy

## Threat model

`chatterino-yt-chat` is a local read-only plugin that reads public YouTube Live Chat data and renders it into Chatterino.

Primary risks:

- malformed/hostile remote payloads
- URL abuse and host redirection
- excessive logging of sensitive fields
- persistence corruption

## Network surface

HTTPS-only, allowlisted hosts:

- `www.youtube.com`
- `youtube.com`
- `m.youtube.com`
- `youtu.be`

No third-party backends, no analytics, no telemetry.

## Filesystem surface

Plugin reads/writes only its local state files:

- `YT_CHAT.json`
- `YT_CHAT.json.bak`

No executable downloads, no dynamic code loading.

## Logging policy

Production logs include only high-level state/error metadata.
Never log API keys, continuations, cookies, full payloads, or full user message content.
Debug logging is off by default.

## Vulnerability reporting

Open a private security report through repository security advisories or create an issue without sensitive exploit details.

## Dependencies

- Lua runtime in Chatterino plugin host
- bundled `libs/json.lua`

No Node.js, npm, pnpm, Python runtime dependencies.

## Update policy

- Stable releases are tagged (`vX.Y.Z`) and include SHA-256 checksums.
- Security fixes are released in patch versions with changelog entries.
