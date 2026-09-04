# Contributing

## Development flow

1. Keep changes scoped and traceable.
2. Add/update fixtures and tests for any renderer/action change.
3. Run local checks:
   - `scripts/test.sh`
   - `scripts/validate_fixtures.sh`
   - `& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File scripts/install_test.ps1`
   - Verify reproducible packaging with the commands below.
4. Update `COMPATIBILITY.md` when support changes.
5. Update `CHANGELOG.md` and `docs/validation/release-notes.md` for
   release-impacting changes.

Release tags must match the version in `info.json` exactly. The release ZIP must
contain `install-or-update.cmd`, `scripts/install.ps1`, the plugin and vendored
library files, `LICENSE` and `NOTICE.md`.

```bash
VERSION="$(jq -r .version info.json)"
scripts/build_release.sh "$VERSION"
HASH1="$(sha256sum "dist/chatterino-yt-chat-$VERSION.zip" | cut -d' ' -f1)"
scripts/build_release.sh "$VERSION"
HASH2="$(sha256sum "dist/chatterino-yt-chat-$VERSION.zip" | cut -d' ' -f1)"
test "$HASH1" = "$HASH2"
```

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

Release pull requests must explain how installation and later updates work
after merge.
