# Performance validation

Executed by `tests/perf/load_spec.lua` (mocked Chatterino + controlled
HTTP; run via `scripts/test.sh`). Last run: 2026-07-19, 1301 assertions
green across the suite (VAL-010 in TRACKER.md).

## Scenarios covered

| Scenario | Implementation | Result |
| --- | --- | --- |
| 1 channel, active stream | polling chain per video | single request chain per `videoId` |
| 10 offline channels | offline monitor, one timer | exactly 1 check per channel per backoff step |
| 5 concurrent streams | 5 polling loops | 5 requests per round, no cross-talk |
| 1 stream in 3 splits | fan-out delivery | 240 msgs across 2 splits from 1 request each |
| High activity | 120 msg/poll × 120 polls × 5 streams | 72k events processed, state bounded |
| Hours of runtime | 3 h simulated clock | ~39 offline checks/channel (30/60/120/300 cap), 1 pending timer |

## Bounds verified

- dedupe cache: ≤ 5000 ids/stream, 30 min TTL, purged with the stream.
- rate-limit buckets: ≤ 256, evicted oldest-first.
- log dedupe table: ≤ 512 keys.
- pending timers: ≤ active streams + 1 offline monitor + 1 debounce.
- persistence: zero writes during pure chat traffic; writes only on
  configuration changes, debounced, content-compared.
- response size caps: 4 MiB chat, 8 MiB watch page.

## What is NOT covered here

Real Chatterino GUI memory/CPU over hours — see
`docs/validation/chatterino-install.md` for the on-device validation and
`manual-checklist.md` for the long-run soak step.
