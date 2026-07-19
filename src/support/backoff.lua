local Backoff = {}

local function rand_jitter(max)
  return math.random() * (tonumber(max) or 0)
end

function Backoff.offline_attempt_delay(attempt, options)
  local cfg = options or {}
  local schedule = cfg.schedule or { 30, 60, 120, 300 }
  local max = cfg.max_seconds or 300
  local jitter = cfg.jitter_seconds or 3
  local idx = math.max(1, math.min(#schedule, tonumber(attempt) or 1))
  local base = tonumber(schedule[idx]) or 30
  if base > max then
    base = max
  end
  return base + rand_jitter(jitter)
end

function Backoff.chat_error_delay(attempt, retry_after_seconds)
  local max = 30
  local given = tonumber(retry_after_seconds)
  if given and given > 0 then
    return math.min(given, max)
  end
  local n = tonumber(attempt) or 1
  local base = math.min(max, 2 ^ math.min(n, 5))
  return base + rand_jitter(0.6)
end

return Backoff
