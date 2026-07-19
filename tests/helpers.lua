local json = require("libs/json")

local Helpers = {}

--- Loads a JSON fixture relative to the repository root.
function Helpers.load_fixture(path)
  local f = assert(io.open(path, "r"), "missing fixture: " .. path)
  local raw = f:read("a")
  f:close()
  local decoded = json.decode(raw)
  assert(type(decoded) == "table", "invalid fixture json: " .. path)
  return decoded
end

--- First key of a table (action/renderer dispatch helper for specs).
function Helpers.first_key(tbl)
  for k in pairs(tbl) do
    return k
  end
  return nil
end

return Helpers
