local json = require "json"

require "constants"
require "mm2plHelper"

local settingsPropertyName = "settings"
local channelsPropertyName = "channels"

local STREAMS_FILE_NAME = "streams.json"
local STREAMS_FILE_DEFAULT_CONTENT = [[{
  "]] .. settingsPropertyName .. [[": {},
  "]] .. channelsPropertyName .. [[": {}
}]]

function StreamFile_Create_If_Not_Exists()
  if FileExists(STREAMS_FILE_NAME) ~= nil then
    local f, e = io.open(STREAMS_FILE_NAME, "w+")
    assert(f, e)
    f:write(STREAMS_FILE_DEFAULT_CONTENT):flush()
    f:seek("set", 0)
    local data  = f:read("a")
    print("StreamFile_Create_If_Not_Exists", data)
    f:close()
  end
end

---@param streamer string
---@param split string
function StreamFile_Create_Streamer(streamer, split)
  local f, e = io.open(STREAMS_FILE_NAME, "w+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")
  print("StreamFile_Create_Streamer 1", rawStreams)

  ---@type table
  local streams = json.decode(rawStreams)

  streams[channelsPropertyName][streamer] = {
    ["split"] = { split }
  }

  f:write(json.encode(streams)):flush()
  f:seek("set", 0)
  local data = f:read("a")
  print("StreamFile_Create_Streamer", data)
  f:close()
end

---@param streamer string
function StreamFile_Read_Streamer(streamer)
  local f, e = io.open(STREAMS_FILE_NAME, "w+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")

  print(rawStreams)

  f:close()

  ---@type table
  local streams = json.decode(rawStreams)

  return OptionalChain(streams, channelsPropertyName, streamer)
end

---@param streamer string
---@param split string
function StreamFile_Add_Split_To_Streamer(streamer, split)
  local f, e = io.open(STREAMS_FILE_NAME, "w+")
  assert(f, e)

  f:seek("set", 0)
  ---@type string
  local rawStreams = f:read("a")

  print("StreamFile_Add_Split_To_Streamer", rawStreams)

  ---@type table
  local streams = json.decode(rawStreams)

  local splits = OptionalChain(streams, channelsPropertyName, streamer, "split")

  if splits ~= nil then
    streams[channelsPropertyName][streamer]["split"].insert(split)
  else
    streams[channelsPropertyName][streamer]["split"] = { split }
  end

  f:write(json.encode(streams)):flush()
  f:seek("set", 0)
  local data = f:read("a")
  print("StreamFile_Add_Split_To_Streamer", data)
  f:close()
end
