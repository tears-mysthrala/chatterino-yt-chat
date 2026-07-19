local RateLimit = {}

local buckets = {}

local function now_ms()
  return math.floor(os.clock() * 1000)
end

function RateLimit.allow(key, window_ms, max_hits)
  if type(key) ~= "string" or key == "" then
    return false
  end
  local window = tonumber(window_ms) or 1000
  local max = tonumber(max_hits) or 1
  local ts = now_ms()
  local bucket = buckets[key]
  if bucket == nil or (ts - bucket.started_at) > window then
    buckets[key] = { hits = 1, started_at = ts }
    return true
  end
  if bucket.hits >= max then
    return false
  end
  bucket.hits = bucket.hits + 1
  return true
end

function RateLimit.reset(key)
  buckets[key] = nil
end

return RateLimit
