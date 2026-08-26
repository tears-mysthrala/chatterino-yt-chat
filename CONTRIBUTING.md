# Contributing

## Development flow

1. Keep changes scoped and traceable.
2. Add/update fixtures and tests for any renderer/action change.
3. Run local checks:
   - `scripts/test.sh`
4. Update `COMPATIBILITY.md` when support changes.
5. Update `CHANGELOG.md` for release-impacting changes.

## Rules

- Keep plugin read-only.
- Do not add telemetry or credential handling.
- Keep network host allowlist strict.
- Preserve source attribution from upstream `yt-chat`.

## Platform-neutral contract

Keep YouTube discovery, Innertube polling and renderer normalization separate
from `src/overlay/publisher.lua`. The publisher must follow the canonical
[multichat event contract](https://github.com/tears-mysthrala/chatterino-multichat-overlay/blob/main/CONTRIBUTING.md), remain optional and fail harmlessly when the overlay is absent.

Stable message IDs must use the `yt-chat-` prefix. New renderer support requires
redacted fixtures, malformed-input tests and a useful plain-text fallback.

## Update notifications

Expose SemVer and the canonical repository through `info.json`. A shared notifier
may check stable GitHub releases at most once every 24 hours and show a
Chatterino system message. It must be disableable and must never download,
replace or execute plugin files automatically.
