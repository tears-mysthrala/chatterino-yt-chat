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
