local Validation = require("src.support.validation")

local Url = {}

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
    local short = path:match("^/([%w_-]+)$")
    if short then
      return {
        canonical = "https://www.youtube.com/watch?v=" .. short,
        kind = "video",
        video_id = short
      }
    end
  end

  if path:match("^/watch$") and params.v then
    return {
      canonical = "https://www.youtube.com/watch?v=" .. params.v,
      kind = "video",
      video_id = params.v
    }
  end

  local live_video = path:match("^/live/([%w_-]+)$")
  if live_video then
    return {
      canonical = "https://www.youtube.com/watch?v=" .. live_video,
      kind = "video",
      video_id = live_video
    }
  end

  local channel_id = path:match("^/channel/(UC[%w_-]+)")
  if channel_id then
    return {
      canonical = "https://www.youtube.com/channel/" .. channel_id .. "/live",
      kind = "channel",
      channel_id = channel_id
    }
  end

  local handle = path:match("^/@([%w%._-]+)")
  if handle then
    local is_live = path:match("/live$")
    return {
      canonical = "https://www.youtube.com/@" .. handle .. (is_live and "/live" or "/live"),
      kind = "channel_handle",
      handle = handle
    }
  end

  if path:match("^/channel/UC[%w_-]+/live$") then
    return {
      canonical = "https://www.youtube.com" .. path,
      kind = "channel"
    }
  end

  return {
    canonical = raw,
    kind = "unknown"
  }, nil
end

return Url
