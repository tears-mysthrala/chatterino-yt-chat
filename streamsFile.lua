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

---@param streamer string
---@param split string
function StreamFile_Create_Streamer(streamer, split)
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")

  ---@type table
  local streams = json.decode(rawStreams)

  streams[channelsPropertyName][streamer] = {
    [splitsPropertyName] = { split }
  }

  f:seek("set", 0)
  f:write(json.encode(streams)):flush()
  f:close()
end

---@param streamer string
function StreamFile_Read_Streamer(streamer)
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")

  f:close()

  ---@type table
  local streams = json.decode(rawStreams)

  return OptionalChain(streams, channelsPropertyName, streamer)
end

---@param streamer string
---@param split string
function StreamFile_Add_Split_To_Streamer(streamer, split)
  local f, e = io.open(STREAMS_FILE_NAME, "r+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")

  ---@type table
  local streams = json.decode(rawStreams)

  local splits = OptionalChain(streams, channelsPropertyName, streamer, splitsPropertyName)

  if splits ~= nil then
    table.insert(streams[channelsPropertyName][streamer][splitsPropertyName], split)
  else
    streams[channelsPropertyName][streamer][splitsPropertyName] = { split }
  end

  f:seek("set", 0)
  f:write(json.encode(streams)):flush()
  f:close()
end

---@param streamData string
---@param split string
function StreamData_Has_Split(streamData, split)
  return Table_Has_Value(streamData[splitsPropertyName], split)
end
