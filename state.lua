require "utils"

IO_LOCK = false

ACTIVE_STREAMS = {}

---@param videoId string
---@param splits table
function Add_To_Active_Streams(videoId, splits)
  ACTIVE_STREAMS[videoId] = splits
end

---@param videoId string
function Is_Active_Stream_VideoId_Active(videoId)
  return Table_Has_Value(ACTIVE_STREAMS, videoId)
end

function Get_Active_Stream_Splits(videoId)
  return ACTIVE_STREAMS[videoId]
end

---@param videoId string
function Remove_From_Active_Streams(videoId)
  ACTIVE_STREAMS[videoId] = nil
end
