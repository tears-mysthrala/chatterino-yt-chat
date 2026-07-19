local ActiveStreams = {
  by_video = {},
  dedupe = {},
  offline_attempts = {},
  in_flight = {}
}

local DEDUPE_LIMIT = 5000
local DEDUPE_TTL_MS = 30 * 60 * 1000

-- Injectable wall clock (ms) for tests.
ActiveStreams._now = function()
  return os.time() * 1000
end

local function ensure_video(video_id)
  local bucket = ActiveStreams.by_video[video_id]
  if not bucket then
    bucket = { splits = {}, channel_name = nil }
    ActiveStreams.by_video[video_id] = bucket
  end
  return bucket
end

function ActiveStreams.add_stream(video_id, channel_name, splits)
  local bucket = ensure_video(video_id)
  bucket.channel_name = channel_name or bucket.channel_name
  local existing = {}
  for _, s in ipairs(bucket.splits) do
    existing[s] = true
  end
  for _, split in ipairs(splits or {}) do
    if not existing[split] then
      table.insert(bucket.splits, split)
      existing[split] = true
    end
  end
end

function ActiveStreams.remove_split(video_id, split)
  local bucket = ActiveStreams.by_video[video_id]
  if not bucket then
    return
  end
  local keep = {}
  for _, s in ipairs(bucket.splits) do
    if s ~= split then
      table.insert(keep, s)
    end
  end
  bucket.splits = keep
  if #bucket.splits == 0 then
    ActiveStreams.cleanup_video(video_id)
  end
end

function ActiveStreams.get_splits(video_id)
  local bucket = ActiveStreams.by_video[video_id]
  if not bucket then
    return {}
  end
  return bucket.splits
end

function ActiveStreams.channel_name(video_id)
  local bucket = ActiveStreams.by_video[video_id]
  return bucket and bucket.channel_name or nil
end

--- Drops every piece of runtime state tied to a video.
function ActiveStreams.cleanup_video(video_id)
  ActiveStreams.by_video[video_id] = nil
  ActiveStreams.dedupe[video_id] = nil
  ActiveStreams.in_flight[video_id] = nil
end

function ActiveStreams.set_in_flight(video_id, active)
  if active then
    ActiveStreams.in_flight[video_id] = true
  else
    ActiveStreams.in_flight[video_id] = nil
  end
end

function ActiveStreams.is_in_flight(video_id)
  return ActiveStreams.in_flight[video_id] == true
end

local function purge_dedupe(cache, now)
  local order = cache.order
  while #order > 0 and (now - order[1].ts) > DEDUPE_TTL_MS do
    cache.index[order[1].id] = nil
    table.remove(order, 1)
  end
end

--- Returns true when the message id was already seen for this video.
--- Cache is size-capped (oldest evicted) and entries expire after 30 min.
function ActiveStreams.seen_message(video_id, message_id)
  if type(message_id) ~= "string" or message_id == "" then
    return false
  end
  local now = ActiveStreams._now()
  local cache = ActiveStreams.dedupe[video_id]
  if not cache then
    cache = { order = {}, index = {} }
    ActiveStreams.dedupe[video_id] = cache
  end
  purge_dedupe(cache, now)
  if cache.index[message_id] then
    return true
  end
  cache.index[message_id] = true
  table.insert(cache.order, { id = message_id, ts = now })
  while #cache.order > DEDUPE_LIMIT do
    local oldest = table.remove(cache.order, 1)
    cache.index[oldest.id] = nil
  end
  return false
end

function ActiveStreams.dedupe_size(video_id)
  local cache = ActiveStreams.dedupe[video_id]
  if not cache then
    return 0
  end
  return #cache.order
end

function ActiveStreams.bump_offline_attempt(key)
  local n = (ActiveStreams.offline_attempts[key] or 0) + 1
  ActiveStreams.offline_attempts[key] = n
  return n
end

function ActiveStreams.reset_offline_attempt(key)
  ActiveStreams.offline_attempts[key] = nil
end

function ActiveStreams.active_video_count()
  local n = 0
  for _ in pairs(ActiveStreams.by_video) do
    n = n + 1
  end
  return n
end

--- Test helper: wipe all runtime state.
function ActiveStreams._reset()
  ActiveStreams.by_video = {}
  ActiveStreams.dedupe = {}
  ActiveStreams.offline_attempts = {}
  ActiveStreams.in_flight = {}
end

return ActiveStreams
