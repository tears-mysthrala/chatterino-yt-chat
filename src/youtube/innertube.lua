local Innertube = {}

local CLIENT_NAME = "WEB"

local function json_escape(value)
  return tostring(value):gsub('[%z\1-\31\\"]', function(ch)
    if ch == '"' then
      return '\\"'
    end
    if ch == "\\" then
      return "\\\\"
    end
    return string.format("\\u%04x", ch:byte())
  end)
end

function Innertube.default_headers(request)
  request:set_header("User-Agent", "facebookexternalhit/")
  request:set_header("Accept-Language", "en")
end

function Innertube.live_chat_url(api_key)
  return "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=" .. json_escape(api_key)
end

function Innertube.live_chat_replay_url(api_key)
  return "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat_replay?key=" .. json_escape(api_key)
end

function Innertube.build_payload(client_version, continuation)
  return '{"context":{"client":{"clientVersion":"' .. json_escape(client_version) ..
      '","clientName":"' .. CLIENT_NAME .. '"}},"continuation":"' .. json_escape(continuation) .. '"}'
end

return Innertube
