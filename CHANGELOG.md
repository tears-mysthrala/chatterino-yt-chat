# Changelog

## 1.1.0 - Unreleased

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
