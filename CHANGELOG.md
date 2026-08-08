# Changelog

## 1.3.0 - Unreleased

- Accepts bare YouTube handles such as `/yt-chat @creator`.
- Adds the compact `auto` command to persist a handle-to-conversation binding
  and reconnect automatically whenever that channel goes live.

## 1.2.1 - 2026-08-08

- Adds complete Spanish aliases and localized completion for every operational
  subcommand while retaining the English command set.
- Explains explicitly that Chatterino 2.5.5 cannot expose plugin configuration
  in its native Settings GUI.
- Removes remaining mixed-language labels from the Spanish operational UI.
- Updates GitHub Actions to Node 24-native pinned releases.

## 1.2.0 - 2026-08-08

- Adds persistent Spanish/English operational UI with live language switching.
- Adds local health counters and a content-free diagnostic export for support.
- Bounds delayed-delivery queues and records backpressure instead of allowing
  unbounded growth during abnormal upstream behavior.
- Materializes validated YouTube avatars and stickers when Chatterino exposes
  its new image API, while preserving the 2.5.5 textual fallback.
- Adds schema v5 for the language preference and expands compatibility tests.

## 1.1.0 - Included in 1.2.0 (not separately tagged)

- Adds the visible `▶️ YT` origin marker to rich and degraded messages.
- Replaces polling slowdown with a true ordered presentation-delay queue.
- Adds `list`, `status`, `pause`, `resume`, `remove`, `config`, `export`, and
  `import` operations plus command completion.
- Adds bounded operational status without exposing tokens or message content.
- Persists paused channels and configuration schema v4.
- Detects future image API support while retaining the Chatterino 2.5.5 text
  fallback; Settings GUI integration remains blocked by the stable upstream API.

## 1.0.0 - 2026-07-19

First stable release of `chatterino-yt-chat` as an independent project,
derived from the experimental `yt-chat` plugin in
[Remahy/Chatterino-Plugins](https://github.com/Remahy/Chatterino-Plugins)
(original author: kararty, MIT license; relevant git history preserved via
subtree split).

### Full YouTube Live Chat coverage (read-only)

- Ordinary messages: multi-run text, Unicode emoji (native), custom channel
  emotes (textual), links (redirect-unwrapped), author badges and roles
  (owner/moderator/member with months/verified), timestamps, stable ids.
- Economy: Super Chat (amount verbatim + tier color highlight), Super
  Sticker (alt text), donation announcements, legacy paid messages.
- Memberships: new, milestone (tenure + level + message), gift purchases
  (×N), gift receptions.
- Moderation: single-message deletions and by-author purges applied
  in-place via `find_message_by_id` + `replace_message` (Chatterino 2.5.x),
  with unequivocal system-event fallback; replacements/edits.
- Pins: banner events with pinned content, dedupe-safe ids, unpin events.
- Polls: open/update (options, ratios, totals, throttled)/close/results.
- System: mode changes (slow/members/subscribers), engagement notices,
  tooltips, stream end + return to offline watch.
- Tickers: paid message / sticker / sponsor tickers with full detail.
- Placeholders/reactions coalesced per window; placeholder→message
  resolution delivered.
- Unknown renderers/actions: visible safe fallback, rate-limited redacted
  logging, anonymized debug samples.

### Infrastructure

- Continuation-driven polling honoring YouTube `timeoutMs` (clamped
  500 ms–15 s, fallback 1 s, jitter), single polling loop per stream,
  in-flight request guard, error taxonomy (fatal 400/403/404 vs
  transient), exponential backoff ≤ 30 s.
- Offline channel monitor: 30/60/120/300 s backoff + jitter, one check
  per channel regardless of splits, single timer chain.
- Persistence: schema v2 with versioned migrations, atomic-within-sandbox
  writes (tmp+verify+`.bak`), corruption recovery, write-on-change,
  debounced flusher, guaranteed write-lock release.
- Security: HTTPS allowlist (`www.youtube.com` family), defensive input
  validation everywhere, no `os`/`load` usage, no telemetry, redacted
  bounded logs with levels.
- Monotonic clock module (Chatterino's sandbox has no `os` library).

### Quality

- 1301-assertion suite: unit, integration harness (mocked Chatterino),
  defensive fuzzing (400 random trees + degenerate cases), load scenarios
  (5 streams, 10 offline channels, 3 h simulated).
- Fixtures: anonymized real captures from `get_live_chat` plus
  structure-verified synthetic fixtures for every supported
  action/renderer.
- Reproducible ZIP build + SHA-256; CI with lint, tests, fixture/schema
  validation, secret scan and host allowlist check.

### Compatibility

- Chatterino 2.5.x (verified against v2.5.5 plugin API). See
  [COMPATIBILITY.md](COMPATIBILITY.md) for the full action/renderer matrix
  and documented visual degradations.
