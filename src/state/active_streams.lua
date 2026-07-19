local ActiveStreams = {
  by_video = {},
  dedupe = {},
  offline_attempts = {},
  in_flight = {}
}

local DEDUPE_LIMIT = 5000

local function ensure_video(video_id)
  local bucket = ActiveStreams.by_video[video_id]
  if not bucket then
    bucket = { splits = {}, channel_name = nil, continuation = nil }
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
    ActiveStreams.by_video[video_id] = nil
    ActiveStreams.dedupe[video_id] = nil
    ActiveStreams.in_flight[video_id] = nil
  end
end

function ActiveStreams.get_splits(video_id)
  local bucket = ActiveStreams.by_video[video_id]
  if not bucket then
    return {}
  end
  return bucket.splits
end

function ActiveStreams.set_in_flight(video_id, active)
  ActiveStreams.in_flight[video_id] = active == true
end

function ActiveStreams.is_in_flight(video_id)
  return ActiveStreams.in_flight[video_id] == true
end

function ActiveStreams.seen_message(video_id, message_id)
  if type(message_id) ~= "string" or message_id == "" then
    return false
  end
  local cache = ActiveStreams.dedupe[video_id]
  if not cache then
    cache = { order = {}, index = {} }
    ActiveStreams.dedupe[video_id] = cache
  end
  if cache.index[message_id] then
    return true
  end
  cache.index[message_id] = true
  table.insert(cache.order, message_id)
  if #cache.order > DEDUPE_LIMIT then
    local oldest = table.remove(cache.order, 1)
    cache.index[oldest] = nil
  end
  return false
end

function ActiveStreams.bump_offline_attempt(key)
  local n = (ActiveStreams.offline_attempts[key] or 0) + 1
  ActiveStreams.offline_attempts[key] = n
  return n
end

function ActiveStreams.reset_offline_attempt(key)
  ActiveStreams.offline_attempts[key] = 0
end

return ActiveStreams
