local Backoff = {}

-- Injectable RNG (returns [0,1)); tests override to force jitter = 0.
Backoff._random = math.random

local DEFAULT_SCHEDULE = { 30, 60, 120, 300 }

local function rand_jitter(max)
  return Backoff._random() * (tonumber(max) or 0)
end

--- Offline-channel check delay per attempt: 30s, 60s, 120s, then 300s max,
--- plus small jitter. Configurable within safe ranges via options.
function Backoff.offline_attempt_delay(attempt, options)
  local cfg = options or {}
  local schedule = cfg.schedule or DEFAULT_SCHEDULE
  local max = cfg.max_seconds or 300
  local jitter = cfg.jitter_seconds or 3
  local idx = math.max(1, math.min(#schedule, tonumber(attempt) or 1))
  local base = tonumber(schedule[idx]) or 30
  if base > max then
    base = max
  end
  return base + rand_jitter(jitter)
end

--- Chat polling error delay: exponential 2^n seconds capped at 30s,
--- honoring Retry-After when provided (also capped), plus jitter.
function Backoff.chat_error_delay(attempt, retry_after_seconds)
  local max = 30
  local given = tonumber(retry_after_seconds)
  if given and given > 0 then
    return math.min(given, max) + rand_jitter(0.6)
  end
  local n = tonumber(attempt) or 1
  local base = math.min(max, 2 ^ math.min(n, 5))
  return base + rand_jitter(0.6)
end

return Backoff
