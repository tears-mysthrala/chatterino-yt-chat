local Validation = require("src.support.validation")

local Url = {}

local VIDEO_ID_PATTERN = "^[%w_-]+$"
local HANDLE_PATTERN = "^@?[%w%._-]+$"

local function trim(s)
  if type(s) ~= "string" then
    return ""
  end
  return s:match("^%s*(.-)%s*$")
end

local function parse_query(query)
  local out = {}
  if type(query) ~= "string" then
    return out
  end
  for pair in query:gmatch("([^&]+)") do
    local key, value = pair:match("^([^=]+)=?(.*)$")
    if key then
      out[key] = value
    end
  end
  return out
end

local function valid_video_id(id)
  return type(id) == "string" and #id >= 6 and #id <= 32 and id:match(VIDEO_ID_PATTERN) ~= nil
end

local function valid_handle(handle)
  return type(handle) == "string" and #handle >= 1 and #handle <= 64 and handle:match(HANDLE_PATTERN) ~= nil
end

local function video_result(video_id)
  if not valid_video_id(video_id) then
    return nil, "invalid_video_id"
  end
  return {
    canonical = "https://www.youtube.com/watch?v=" .. video_id,
    kind = "video",
    video_id = video_id
  }
end

local function channel_id_result(channel_id)
  if not valid_video_id(channel_id) then
    return nil, "invalid_channel_id"
  end
  return {
    canonical = "https://www.youtube.com/channel/" .. channel_id .. "/live",
    kind = "channel",
    channel_id = channel_id
  }
end

local function handle_result(handle)
  if not valid_handle(handle) then
    return nil, "invalid_handle"
  end
  return {
    canonical = "https://www.youtube.com/@" .. handle .. "/live",
    kind = "channel_handle",
    handle = handle
  }
end

--- Normalizes accepted YouTube URL forms into a canonical watch or /live URL.
--- Returns result table or nil + error. Only HTTPS on official hosts passes.
function Url.normalize(input)
  local raw = trim(input)
  if not Validation.is_safe_https_youtube(raw) then
    return nil, "invalid_url"
  end

  local host = Validation.extract_host(raw)
  local path = raw:match("^https://[^/]+(/[^?#]*)") or "/"
  local query = raw:match("%?([^#]+)")
  local params = parse_query(query)

  if host == "youtu.be" or host == "www.youtu.be" then
    local short = path:match("^/([%w_-]+)/?$")
    if short then
      return video_result(short)
    end
    return nil, "unsupported_url"
  end

  if path:match("^/watch/?$") and params.v then
    return video_result(params.v)
  end

  local live_video = path:match("^/live/([%w_-]+)/?$")
  if live_video then
    return video_result(live_video)
  end

  local shorts_video = path:match("^/shorts/([%w_-]+)/?$")
  if shorts_video then
    return video_result(shorts_video)
  end

  local channel_id = path:match("^/channel/(UC[%w_-]+)/?")
  if channel_id then
    return channel_id_result(channel_id)
  end

  local handle = path:match("^/@([%w%._-]+)")
  if handle then
    return handle_result(handle)
  end

  -- Bare channel vanity paths (/c/<name>, /user/<name>) resolve via /live
  -- redirect on YouTube's side; only allow plain safe names.
  local vanity = path:match("^/c/([%w%._-]+)/?$") or path:match("^/user/([%w%._-]+)/?$")
  if vanity and valid_handle(vanity) then
    return {
      canonical = "https://www.youtube.com/" .. (path:match("^/c/") and "c/" or "user/") .. vanity .. "/live",
      kind = "channel_vanity",
      handle = vanity
    }
  end

  return nil, "unsupported_url"
end

return Url
