local Innertube = {}

function Innertube.default_headers(request)
  request:set_header("User-Agent", "facebookexternalhit/")
  request:set_header("Accept-Language", "en")
end

function Innertube.live_chat_url(api_key)
  return "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=" .. api_key
end

function Innertube.build_payload(client_version, continuation)
  return [[
{
  "context": {
    "client": {
      "clientVersion": "]] .. client_version .. [[",
      "clientName": "WEB"
    }
  },
  "continuation": "]] .. continuation .. [["
}
]]
end

return Innertube
