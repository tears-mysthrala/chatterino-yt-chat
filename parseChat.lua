local json = require "json"

require "mm2plHelper"

---@param action table
local add_chat = function(data, action)
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
  local trimmedName = Trim5(name)

  local messageRuns = OptionalChain(textRenderer, "message", "runs")

  local text = ""

  if messageRuns then
    for _, textRun in ipairs(messageRuns) do
      text = text .. (OptionalChain(textRun, "text") or "")
    end
  end

  local timestamp = OptionalChain(textRenderer, "timestampUsec")
  local id = OptionalChain(textRenderer, "id")

  print(json.encode(textRenderer))


  local message = c2.Message.new({
    id = "yt-chat-" .. id,
    message_text = text,
    server_received_time = timestamp,
    elements = {
      {
        type = "text",
        text = "YT",
        color = "system"
      },
      {
        type = "timestamp",
        time = timestamp
      },
      {
        type = "text",
        text = trimmedName .. ":",
        color = Get_Color(trimmedName),
      },
      {
        type = "text",
        text = text
      }
    }
  })

  local splits = Get_Active_Stream_Splits(data["videoId"])
  for _, split in ipairs(splits) do
    local channel = c2.Channel.by_name(split)
    -- channel:add_system_message(text)
    if channel then
      channel:add_message(message)
    end
  end

  -- add_to_message_id_cache(id)
end

---@param youtubeData table
local add_chats = function(data, youtubeData)
  local actions = OptionalChain(youtubeData, "continuationContents", "liveChatContinuation", "actions")

  if actions == nil then
    return
  end

  for _, action in ipairs(actions) do
    add_chat(data, action)
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

---@param data { ["channelId"]:string, ["videoId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
---@param result c2.HTTPResponse
local parse_live_chat_response = function(data, result)
  local status = result:status()

  if status >= 300 then
    Remove_From_Active_Streams(data["videoId"])
    return
  end

  local stringJson = result:data()
  local youtubeData = json.decode(stringJson)

  if type(youtubeData) ~= "table" then
    Remove_From_Active_Streams(data["videoId"])
    return
  end

  add_chats(data, youtubeData)

  local newContinuation = get_next_continuation(youtubeData)

  if newContinuation == nil then
    Remove_From_Active_Streams(data["videoId"])
    return
  end

  --c2.later(function()
    Read_YouTube_Chat(
      {
        ["channelId"] = data["channelId"],
        ["videoId"] = data["videoId"],
        ["apiKey"] = data["apiKey"],
        ["clientVersion"] = data["clientVersion"],
        ["continuation"] = newContinuation
      }
    )
  --end, 500)
end

---@param data { ["channelId"]:string, ["videoId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
function Read_YouTube_Chat(data)
  local videoId = data["videoId"]
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
  request:on_success(function(result) parse_live_chat_response(data, result) end)
  request:on_error(function(result)
    print("Something went wrong reading chat from videoId " ..
      videoId .. " :" .. result:error())
  end)
  request:execute()
end
