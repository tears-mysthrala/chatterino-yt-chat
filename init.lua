require "addStream"
require "utils"
require "systemMessages"
require "streamsFile"
require "state"

--local message_id_cache = {}
--local add_to_message_id_cache = function (id)
-- message_id_cache[# message_id_cache+1] = id
--end

local read_stream_data = function()
  if IO_LOCK == true then
    return
  end

  IO_LOCK = true



  IO_LOCK = false
end

-- c2.later(read_stream_data, 500)

--[[
local request_url = function(url, channel)
  local request = c2.HTTPRequest.create(c2.HTTPMethod.Get, url)
  Mutate_Request_Default_Headers(request)
  request:on_success(function(result) parse_data(result, channel) end)
  request:on_error(function(result) print("Something went wrong reading url " .. url .. " :" .. result:error()) end)
  request:execute()
end
]]--

---@param ctx CommandContext
local cmd_yt_chat = function(ctx)
  local channel = ctx.channel

  if #ctx.words == 1 then
    Warn_No_URL_Provided(channel)
    return
  end

  local url = ctx.words[2]

  if Is_Valid_URL(url) == false then
    Warn_URL_Not_YouTube(channel, url)
    return
  end

  Log_Reading_URL(channel, url)

  IO_LOCK = true
  Initialize_URL(channel, url)
end

c2.register_command("/yt-chat", cmd_yt_chat)
