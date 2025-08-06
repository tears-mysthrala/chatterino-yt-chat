local JSON = require "JSON"
require "mm2plHelper"

--local message_id_cache = {};
--local add_to_message_id_cache = function (id)
-- message_id_cache[# message_id_cache+1] = id
--end

-- Major credits to https://github.com/Agash/YTLiveChat for the original regexes

local LIVE_ID_REGEX = '<link rel="canonical" href="https://www%.youtube%.com/watch%?v=([^"]+)">'
local API_KEY_REGEX = '"INNERTUBE_API_KEY"%s*:%s*"([^"]*)"'
local CLIENT_VERSION_REGEX = '"INNERTUBE_CONTEXT_CLIENT_VERSION"%s*:%s*"([^"]*)"'
local CONTINUATION_REGEX = '"continuation"%s*:%s*"([^"]*)"'
local VIDEO_ID_REGEX = '"videoId"%s*:%s*"([^"]*)"'

---@param request c2.HTTPRequest
local mutate_request_default_headers = function(request)
  request:set_header("User-Agent", "facebookexternalhit/")
  request:set_header("Accept-Language", "en")
end

---@param action table
---@param channel c2.Channel
local add_chat = function(action, channel)
  local item = OptionalChain(action, "addChatItemAction", "item")

  if item == nil then
    print("Missing addChatItemAction.item")
    return
  end

  --- item could be anything, but for now we're reading only text
  local textRenderer = OptionalChain(item, "liveChatTextMessageRenderer")

  if textRenderer == nil then
    print("Hit non normal message type: " .. JSON:encode(item))
    return
  end

  local name = OptionalChain(textRenderer, "authorName", "text") or
      OptionalChain(textRenderer, "authorName", "simpleText") or "[YouTube chatter]"

  local messageRuns = OptionalChain(textRenderer, "message", "runs")

  local text = ""

  if messageRuns then
    for _, textRun in ipairs(messageRuns) do
      text = text .. (OptionalChain(textRun, "text") or "")
    end
  end

  local timestamp = OptionalChain(textRenderer, "timestampUsec")
  local id = OptionalChain(textRenderer, "id")

  local message = c2.Message.new({
    id = "yt-chat-" .. id,
    elements = {
      {
        type = "timestamp",
        time = timestamp
      },
      {
        type = "text",
        text = name .. ":",
        color = "system"
      },
      {
        type = "text",
        text = text
      }
    }
  })

  -- channel:add_system_message(text)
  channel:add_message(message)

  -- add_to_message_id_cache(id)
end

---@param json table
---@param channel c2.Channel
local add_chats = function(json, channel)
  local actions = OptionalChain(json, "continuationContents", "liveChatContinuation", "actions")

  if actions == nil then
    return
  end

  for _, action in ipairs(actions) do
    add_chat(action, channel)
  end
end

---@param json table
local get_next_continuation = function(json)
  local nextContinuation = nil

  local CS = OptionalChain(json, "continuationContents", "liveChatContinuation", "continuations")

  if CS then
    nextContinuation = CS[1]
  end

  local continuation = nil

  if nextContinuation then
    local ICDC = OptionalChain(nextContinuation, "invalidationContinuationData", "continuation")
    local TCDC = OptionalChain(nextContinuation, "timedContinuationData", "continuation")

    continuation = ICDC or TCDC
  end

  if continuation == nil then
    continuation = OptionalChain(json, "invalidationContinuationData", "continuation")
  end

  return continuation
end

---@param data { ["liveId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
---@param result c2.HTTPResponse
---@param channel c2.Channel
local parse_live_chat_response = function(data, result, channel)
  local status = result:status()

  if status >= 300 then
    channel:add_system_message("Could not read chat, status code: " .. status)
    return
  end

  local stringJson = result:data()
  local json = JSON:decode(stringJson)

  if type(json) ~= "table" then
    channel:add_system_message("Could not read chat.")
    return
  end

  add_chats(json, channel)

  local newContinuation = get_next_continuation(json)

  if newContinuation == nil then
    channel:add_system_message("Could not continue reading chat.")
    return
  end

  ---c2.later(function()
    Read_YouTube_Chat(
      {
        ["liveId"] = data["liveId"],
        ["apiKey"] = data["apiKey"],
        ["clientVersion"] = data["clientVersion"],
        ["continuation"] = newContinuation
      },
      channel
    )
  ---end, 500)
end

---@param data { ["liveId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
---@param channel c2.Channel
Read_YouTube_Chat = function(data, channel)
  local liveId = data["liveId"]
  local apiKey = data["apiKey"]
  local clientVersion = data["clientVersion"]
  local continuation = data["continuation"]

  local request = c2.HTTPRequest.create(c2.HTTPMethod.Post,
    "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=" .. apiKey)
  mutate_request_default_headers(request)
  request:set_header("Content-Type", "application/json")
  request:set_payload([[
    {
      "context": {
        "client": {
          "clientVersion": "]] .. clientVersion .. [[",
          "clientName": "WEB"
        }
      },
      "continuation": "]] .. continuation .. [["
    }
  ]])
  request:on_success(function(result) parse_live_chat_response(data, result, channel) end)
  request:on_error(function(result)
    print("Something went wrong reading chat from live_id " ..
      liveId .. " :" .. result:error())
  end)
  request:execute()
end

---@param result c2.HTTPResponse
---@param channel c2.Channel
local parse_data = function(result, channel)
  local html = result:data()

  local liveId = html:match(LIVE_ID_REGEX) or html:match(VIDEO_ID_REGEX) or ""

  if liveId == "" then
    channel:add_system_message("Link didn't return video id.")
    return
  end

  local apiKey = html:match(API_KEY_REGEX)

  if apiKey == nil then
    channel:add_system_message("Could not parse stream.")
    return
  end

  local clientVersion = html:match(CLIENT_VERSION_REGEX) or ""
  local continuation = html:match(CONTINUATION_REGEX)

  if continuation == nil then
    channel:add_system_message("There's no chat for this stream.")
    return
  end

  print(liveId .. " | " .. apiKey .. " | " .. clientVersion .. " | " .. continuation)

  Read_YouTube_Chat(
    {
      ["liveId"] = liveId,
      ["apiKey"] = apiKey,
      ["clientVersion"] = clientVersion,
      ["continuation"] = continuation
    },
    channel
  )
end

local request_url = function(url, channel)
  local request = c2.HTTPRequest.create(c2.HTTPMethod.Get, url)
  mutate_request_default_headers(request)
  request:on_success(function(result) parse_data(result, channel) end)
  request:on_error(function(result) print("Something went wrong reading url " .. url .. " :" .. result:error()) end)
  request:execute()
end

---@param url string
local is_valid_url = function(url)
  if type(url) ~= "string" then
    return false
  end

  if url:find("^https://www%.youtube%.com/") == nil then
    return false
  end

  return true
end

---@param ctx CommandContext
local cmd_yt = function(ctx)
  if #ctx.words == 1 then
    ctx.channel:add_system_message("No link provided.")
    return
  end

  local url = ctx.words[2]

  if is_valid_url(url) == false then
    ctx.channel:add_system_message("Link is invalid: " .. url)
    return
  end

  ctx.channel:add_system_message("Reading url: " .. url)

  request_url(url, ctx.channel)
end

c2.register_command("/yt", cmd_yt)
