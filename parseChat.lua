local json = require "json"

require "mm2plHelper"

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
    print("Hit non normal message type: " .. json.encode(item))
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

---@param youtubeData table
---@param channel c2.Channel
local add_chats = function(youtubeData, channel)
  local actions = OptionalChain(youtubeData, "continuationContents", "liveChatContinuation", "actions")

  if actions == nil then
    return
  end

  for _, action in ipairs(actions) do
    add_chat(action, channel)
  end
end

---@param youtubeData table
local get_next_continuation = function(youtubeData)
  local nextContinuation = nil

  local CS = OptionalChain(youtubeData, "continuationContents", "liveChatContinuation", "continuations")

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
    continuation = OptionalChain(youtubeData, "invalidationContinuationData", "continuation")
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
  local youtubeData = json.decode(stringJson)

  if type(youtubeData) ~= "table" then
    channel:add_system_message("Could not read chat.")
    return
  end

  add_chats(youtubeData, channel)

  local newContinuation = get_next_continuation(youtubeData)

  if newContinuation == nil then
    channel:add_system_message("Could not continue reading chat.")
    return
  end

  --c2.later(function()
    Read_YouTube_Chat(
      {
        ["liveId"] = data["liveId"],
        ["apiKey"] = data["apiKey"],
        ["clientVersion"] = data["clientVersion"],
        ["continuation"] = newContinuation
      },
      channel
    )
  --end, 500)
end

---@param data { ["liveId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
---@param channel c2.Channel
function Read_YouTube_Chat (data, channel)
  local liveId = data["liveId"]
  local apiKey = data["apiKey"]
  local clientVersion = data["clientVersion"]
  local continuation = data["continuation"]

  local request = c2.HTTPRequest.create(c2.HTTPMethod.Post,
    "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=" .. apiKey)
  Mutate_Request_Default_Headers(request)
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
