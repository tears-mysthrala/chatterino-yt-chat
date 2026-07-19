# Changelog

## 1.0.0 - 2026-07-19

First stable independent release of `chatterino-yt-chat`.

- Extracted standalone repository from original monorepo plugin history.
- Refactored architecture into `src/youtube`, `src/messages`, `src/state`, `src/support`.
- Added safe URL normalization and YouTube host allowlist.
- Added continuation parsing with defensive timing clamps.
- Added event/action dispatch with unknown fallback.
- Added atomic state persistence with backup recovery.
- Added rate-limited structured logging with redaction.
- Added reproducible ZIP + SHA-256 build scripts.
- Added unit/integration/fuzz baseline test harness and fixtures.
- Added security, compatibility, contribution, and provenance documentation.
