local Html = {}

local MAX_HTML_BYTES = 8 * 1024 * 1024

-- Anchored patterns first (credit: Agash/YTLiveChat for the originals),
-- loose fallbacks after. YouTube reshuffles markup; be tolerant.
local PATTERNS = {
  live_id = '<link rel="canonical" href="https://www%.youtube%.com/watch%?v=([^"]+)">',
  video_id = '"videoId"%s*:%s*"([^"]+)"',
  api_key = '"INNERTUBE_API_KEY"%s*:%s*"([^"]+)"',
  client_version_context = '"INNERTUBE_CONTEXT_CLIENT_VERSION"%s*:%s*"([^"]+)"',
  client_version = '"INNERTUBE_CLIENT_VERSION"%s*:%s*"([^"]+)"',
  client_version_cfg = '"INNERTUBE_CONTEXT"%s*:%s*%b{}',
  continuation = '"continuation"%s*:%s*"([^"]+)"',
  channel_id_anchored = '"channelId"%s*:%s*"([^"]+)","isOwnerViewing"',
  channel_id = '"channelId"%s*:%s*"(UC[^"]+)"',
  channel_name_anchored = '"author"%s*:%s*"([^"]+)","isLowLatencyLiveStream"',
  channel_name = '"ownerChannelName"%s*:%s*"([^"]+)"'
}

local LIVE_MARKERS = {
  '"isLive"%s*:%s*true',
  '"isLiveNow"%s*:%s*true',
  '"liveChatRenderer"',
  '"isLiveContent"%s*:%s*true'
}

local function detect_live(html)
  for _, marker in ipairs(LIVE_MARKERS) do
    if html:find(marker) then
      return true
    end
  end
  return false
end

--- Extracts Innertube metadata from a YouTube watch or /live page.
--- Returns data table (continuation=nil when the channel is offline) or
--- nil + error code ("videoId"|"apiKey"|"clientVersion"|"channelId"|"too_large"|"invalid_html").
function Html.parse_watch_page(html)
  if type(html) ~= "string" then
    return nil, "invalid_html"
  end
  if #html > MAX_HTML_BYTES then
    return nil, "too_large"
  end
  local video_id = html:match(PATTERNS.live_id) or html:match(PATTERNS.video_id)
  if not video_id then
    return nil, "videoId"
  end
  local api_key = html:match(PATTERNS.api_key)
  if not api_key then
    return nil, "apiKey"
  end
  local client_version = html:match(PATTERNS.client_version_context) or html:match(PATTERNS.client_version)
  if not client_version then
    return nil, "clientVersion"
  end
  local channel_id = html:match(PATTERNS.channel_id_anchored) or html:match(PATTERNS.channel_id)
  if not channel_id then
    return nil, "channelId"
  end
  local is_live = detect_live(html)
  local continuation = nil
  if is_live then
    continuation = html:match(PATTERNS.continuation)
    if not continuation then
      return nil, "continuation"
    end
  end
  local channel_name = html:match(PATTERNS.channel_name_anchored) or html:match(PATTERNS.channel_name) or
      channel_id
  return {
    videoId = video_id,
    apiKey = api_key,
    clientVersion = client_version,
    continuation = continuation,
    channelId = channel_id,
    channelName = channel_name,
    isLive = is_live
  }, nil
end

return Html
