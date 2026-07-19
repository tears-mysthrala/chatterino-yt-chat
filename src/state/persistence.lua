local json = require("libs/json")
local Migrations = require("src.state.migrations")
local Logging = require("src.support.logging")

local Persistence = {}

local STATE_FILE = "YT_CHAT.json"
local BACKUP_FILE = "YT_CHAT.json.bak"

local function read_all(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local raw = f:read("a")
  f:close()
  return raw
end

local function safe_decode(raw)
  if type(raw) ~= "string" or raw == "" then
    return nil
  end
  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function write_atomic(path, encoded)
  local tmp = path .. ".tmp"
  local f, err = io.open(tmp, "w")
  if not f then
    return false, err
  end
  f:write(encoded)
  f:flush()
  f:close()

  local existing = read_all(path)
  if existing then
    local b = io.open(BACKUP_FILE, "w")
    if b then
      b:write(existing)
      b:flush()
      b:close()
    end
  end
  os.remove(path)
  local ok, rename_err = os.rename(tmp, path)
  if not ok then
    return false, rename_err
  end
  return true, nil
end

function Persistence.read()
  local data = safe_decode(read_all(STATE_FILE))
  if data == nil then
    data = safe_decode(read_all(BACKUP_FILE))
  end
  if data == nil then
    data = {}
  end
  return Migrations.upgrade(data)
end

function Persistence.write_if_changed(state, previous_hash)
  local encoded = json.encode(Migrations.upgrade(state))
  if encoded == previous_hash then
    return previous_hash, true
  end
  local ok, err = write_atomic(STATE_FILE, encoded)
  if not ok then
    Logging.error("state_write_failed", { error = err })
    return previous_hash, false
  end
  return encoded, true
end

return Persistence
