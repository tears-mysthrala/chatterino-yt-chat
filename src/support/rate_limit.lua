local RateLimit = {}

local MAX_BUCKETS = 256

local buckets = {}

-- Injectable wall clock (milliseconds). Tests override this.
RateLimit._now = function()
  return os.time() * 1000
end

local function evict_if_full(now)
  local count = 0
  local oldest_key, oldest_start
  for key, bucket in pairs(buckets) do
    count = count + 1
    if oldest_start == nil or bucket.started_at < oldest_start then
      oldest_start = bucket.started_at
      oldest_key = key
    end
  end
  if count >= MAX_BUCKETS and oldest_key ~= nil then
    buckets[oldest_key] = nil
  end
end

function RateLimit.allow(key, window_ms, max_hits)
  if type(key) ~= "string" or key == "" then
    return false
  end
  local window = tonumber(window_ms) or 1000
  local max = tonumber(max_hits) or 1
  local ts = RateLimit._now()
  local bucket = buckets[key]
  if bucket == nil or (ts - bucket.started_at) > window then
    if bucket == nil then
      evict_if_full(ts)
    end
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

function RateLimit._size()
  local count = 0
  for _ in pairs(buckets) do
    count = count + 1
  end
  return count
end

function RateLimit._clear()
  buckets = {}
end

return RateLimit
