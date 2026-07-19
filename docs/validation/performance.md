# Performance validation plan

Scenarios:

1. 1 configured channel with active stream.
2. 10 configured channels offline.
3. 5 active streams concurrently.
4. 1 active stream rendered into multiple splits.
5. High activity fixture replay for sustained period.

Checks:

- no duplicate polling per `videoId`
- no duplicate offline timers per channel
- dedupe cache bounded
- state file writes only on config changes
- no unbounded in-memory table growth
