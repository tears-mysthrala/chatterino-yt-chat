require "utils"
require "systemMessages"

---@param channel c2.Channel
---@param data { ["channelId"]:string, ["liveId"]:string, ["apiKey"]:string, ["clientVersion"]:string, ["continuation"]:string }
local initialize_add_stream = function(channel, data)
  StreamFile_Create_If_Not_Exists()

  local split = channel:get_name()

  local streamer = data["channelId"]

  local streamerData = StreamFile_Read_Streamer(streamer)

  if streamerData ~= nil then
    local hasSplit = Table_Has_Value(streamerData["split"], split)
    if hasSplit then
      Warn_Split_Already_Added(channel, streamer, split)
      return
    end

    StreamFile_Add_Split_To_Streamer(streamer, split)
    return
  end

  StreamFile_Create_Streamer(streamer, split)
  IO_LOCK = false
end

---@param channel c2.Channel
---@param url string
---@param result c2.HTTPResponse
local parse_data = function(channel, url, result)
  local html = result:data()

  local liveId = html:match(LIVE_ID_REGEX) or html:match(VIDEO_ID_REGEX)
  if liveId == nil then
    Warn_No_VideoId(channel, url)
    return
  end

  local apiKey = html:match(API_KEY_REGEX)
  if apiKey == nil then
    Warn_No_ApiKey(channel, url)
    return
  end

  local continuation = html:match(CONTINUATION_REGEX)
  if continuation == nil then
    Warn_No_Continuation(channel, url)
    return
  end

  local clientVersion = html:match(CLIENT_VERSION_REGEX)
  if clientVersion == nil then
    Warn_No_Client_Version(channel, url)
    return
  end

  local channelId = html:match(CHANNEL_ID_REGEX)
  if channelId == nil then
    Warn_No_Channel_Id(channel, url)
    return
  end

  return {
    ["liveId"] = liveId,
    ["apiKey"] = apiKey,
    ["clientVersion"] = clientVersion,
    ["continuation"] = continuation,
    ["channelId"] = channelId
  }
end

---@param result c2.HTTPResponse
local handle_result = function(channel, url, result)
  local status = result:status()

  if status ~= 200 then
    Warn_Status_Not_200_URL(channel, url, status)
    return
  end

  local data = parse_data(channel, url, result)

  if data then
    initialize_add_stream(channel, data)
  end
end

---@param channel c2.Channel
---@param url string
function Initialize_URL(channel, url)
  local request = c2.HTTPRequest.create(c2.HTTPMethod.Get, url)

  Mutate_Request_Default_Headers(request)

  request:on_success(function(result) handle_result(channel, url, result) end)

  request:on_error(function(result)
    print("Something went wrong reading url " .. url .. " :" .. result:error())
    Warn_Faulty_URL(channel, url)
  end)

  request:execute()
end
