local json = require "json"

require "constants"
require "mm2plHelper"
require "utils"

local settingsPropertyName = "settings"
local channelsPropertyName = "channels"
local splitsPropertyName = "splits"

local STREAMS_FILE_NAME = "YT_CHAT.json"
local STREAMS_FILE_DEFAULT_CONTENT = [[{
  "]] .. settingsPropertyName .. [[": {},
  "]] .. channelsPropertyName .. [[": {}
}]]

function StreamFile_Create_If_Not_Exists()
  if FileExists(STREAMS_FILE_NAME) then
    return
  end

  local f, e = io.open(STREAMS_FILE_NAME, "w+")
  assert(f, e)
  f:seek("set", 0)
  f:write(STREAMS_FILE_DEFAULT_CONTENT):flush()
  f:close()
end

---@param channel string
---@param split string
function StreamFile_Create_Channel(channel, split)
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawFile = f:read("a")

  ---@type table
  local t = json.decode(rawFile)

  t[channelsPropertyName][channel] = {
    [splitsPropertyName] = { split }
  }

  f:seek("set", 0)
  f:write(json.encode(t)):flush()
  f:close()
end

function StreamFile_Read_Channels()
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawFile = f:read("a")

  f:close()

  ---@type table
  local t = json.decode(rawFile)

  return t[channelsPropertyName]
end

---@param channel string
function StreamFile_Read_Channel(channel)
  local channels = StreamFile_Read_Channels()

  return OptionalChain(channels, channel)
end

---@param channel string
---@param split string
function StreamFile_Add_Split_To_Channel(channel, split)
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawFile = f:read("a")

  ---@type table
  local t = json.decode(rawFile)

  local splits = OptionalChain(t, channelsPropertyName, channel, splitsPropertyName)

  if splits ~= nil then
    table.insert(t[channelsPropertyName][channel][splitsPropertyName], split)
  else
    t[channelsPropertyName][channel][splitsPropertyName] = { split }
  end

  f:seek("set", 0)
  f:write(json.encode(t)):flush()
  f:close()
end

---@param channelData string
---@param split string
function StreamData_Has_Split(channelData, split)
  return Table_Has_Value(channelData[splitsPropertyName], split)
end
