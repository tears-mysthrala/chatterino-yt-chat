---@param request c2.HTTPRequest
function Mutate_Request_Default_Headers(request)
  request:set_header("User-Agent", "facebookexternalhit/")
  request:set_header("Accept-Language", "en")
end

---@param url string
function Is_Valid_URL(url)
  if type(url) ~= "string" then
    return false
  end

  if url:find("^https://www%.youtube%.com/") == nil then
    return false
  end

  return true
end

function FileExists(filename)
   local isPresent = nil
   local f = io.open(filename, "r")

   if f then
      isPresent = true
      f:close()
   end

   return isPresent
end

--- This is MOST DEFINITELY prone to breaking in the future.
--- Channel ids are CASE SENSITIVE on Youtube but Chatterino channels are ALWAYS lowercase.
--- TODO: Create more useful and actually unique names.
---@param streamer string
function GetSplitName(streamer)
  return "/yt:" .. streamer:lower()
end
