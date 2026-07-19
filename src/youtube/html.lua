local Html = {}

local PATTERNS = {
  live_id = '<link rel="canonical" href="https://www%.youtube%.com/watch%?v=([^"]+)">',
  video_id = '"videoId"%s*:%s*"([^"]+)"',
  api_key = '"INNERTUBE_API_KEY"%s*:%s*"([^"]+)"',
  client_version = '"INNERTUBE_CONTEXT_CLIENT_VERSION"%s*:%s*"([^"]+)"',
  continuation = '"continuation"%s*:%s*"([^"]+)"',
  channel_id = '"channelId"%s*:%s*"([^"]+)"',
  channel_name = '"author"%s*:%s*"([^"]+)"'
}

function Html.parse_watch_page(html)
  if type(html) ~= "string" then
    return nil, "invalid_html"
  end
  local video_id = html:match(PATTERNS.live_id) or html:match(PATTERNS.video_id)
  if not video_id then
    return nil, "videoId"
  end
  local api_key = html:match(PATTERNS.api_key)
  if not api_key then
    return nil, "apiKey"
  end
  local client_version = html:match(PATTERNS.client_version)
  if not client_version then
    return nil, "clientVersion"
  end
  local channel_id = html:match(PATTERNS.channel_id)
  if not channel_id then
    return nil, "channelId"
  end
  local continuation = html:match(PATTERNS.continuation)
  local channel_name = html:match(PATTERNS.channel_name) or channel_id
  return {
    videoId = video_id,
    apiKey = api_key,
    clientVersion = client_version,
    continuation = continuation,
    channelId = channel_id,
    channelName = channel_name
  }, nil
end

return Html
