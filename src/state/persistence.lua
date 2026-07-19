local json = require("libs/json")
local Migrations = require("src.state.migrations")
local Logging = require("src.support.logging")

local Persistence = {}

local STATE_FILE = "YT_CHAT.json"
local BACKUP_SUFFIX = ".bak"
local TMP_SUFFIX = ".tmp"

local dir = "."
local writing = false

-- Set to "bak" or "default" when read() had to recover; nil on clean read.
Persistence.last_recovery = nil

-- Injectable wall clock (ms) for the debounce flusher.
Persistence._now = function()
  return os.time() * 1000
end

--- Redirect storage to another directory (tests only).
function Persistence._set_dir(new_dir)
  dir = new_dir or "."
end

local function state_path()
  return dir .. "/" .. STATE_FILE
end

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

--- Coerces arbitrary decoded data into the canonical schema, dropping
--- unknown keys and clamping sizes. Never errors.
function Persistence.validate_schema(data)
  local state = Migrations.upgrade(data)
  local out = {
    schema_version = Migrations.SCHEMA_VERSION,
    settings = {},
    channels = {}
  }
  local defaults = Migrations.default_settings()
  for key, default_value in pairs(defaults) do
    local value = state.settings and state.settings[key]
    if type(default_value) == "boolean" then
      out.settings[key] = value == true
    elseif type(default_value) == "number" then
      out.settings[key] = tonumber(value) or default_value
    elseif type(default_value) == "table" then
      if type(value) == "table" and #value > 0 then
        local list = {}
        for _, item in ipairs(value) do
          local n = tonumber(item)
          if n and #list < 16 then
            list[#list + 1] = n
          end
        end
        out.settings[key] = #list > 0 and list or default_value
      else
        out.settings[key] = default_value
      end
    end
  end
  for key, entry in pairs(state.channels or {}) do
    if type(key) == "string" and #key <= 256 and type(entry) == "table" then
      local splits = {}
      if type(entry.splits) == "table" then
        for _, split in ipairs(entry.splits) do
          if type(split) == "string" and split ~= "" and #split <= 256 and #splits < 64 then
            splits[#splits + 1] = split
          end
        end
      end
      local normalized = { splits = splits }
      for _, field in ipairs({ "channel_id", "handle", "display_name" }) do
        if type(entry[field]) == "string" and entry[field] ~= "" and #entry[field] <= 256 then
          normalized[field] = entry[field]
        end
      end
      out.channels[key] = normalized
    end
  end
  return out
end

local function write_atomic(path, encoded)
  local tmp = path .. TMP_SUFFIX
  local f, err = io.open(tmp, "w")
  if not f then
    return false, err
  end
  f:write(encoded)
  f:flush()
  f:close()

  local existing = read_all(path)
  if existing then
    local b = io.open(path .. BACKUP_SUFFIX, "w")
    if b then
      b:write(existing)
      b:flush()
      b:close()
    end
  end

  os.remove(path)
  local ok, rename_err = os.rename(tmp, path)
  if not ok then
    -- Best effort restore: keep the previous content reachable.
    local backup = read_all(path .. BACKUP_SUFFIX)
    if backup then
      local restore = io.open(path, "w")
      if restore then
        restore:write(backup)
        restore:flush()
        restore:close()
      end
    end
    os.remove(tmp)
    return false, rename_err
  end
  return true, nil
end

function Persistence.read()
  Persistence.last_recovery = nil
  local data = safe_decode(read_all(state_path()))
  if data == nil then
    data = safe_decode(read_all(state_path() .. BACKUP_SUFFIX))
    if data ~= nil then
      Persistence.last_recovery = "bak"
      Logging.warning("state_recovered_from_backup")
    end
  end
  if data == nil then
    Persistence.last_recovery = "default"
    return Persistence.validate_schema({})
  end
  return Persistence.validate_schema(data)
end

--- Writes only when the encoded content changed. A module-level lock
--- prevents overlapping writes and is always released via pcall.
function Persistence.write_if_changed(state, previous_hash)
  if writing then
    return previous_hash, false, "busy"
  end
  writing = true
  local ok, new_hash, write_ok, err = pcall(function()
    local encoded = json.encode(Persistence.validate_schema(state))
    if encoded == previous_hash then
      return previous_hash, true, nil
    end
    local wok, werr = write_atomic(state_path(), encoded)
    if not wok then
      return previous_hash, false, werr
    end
    return encoded, true, nil
  end)
  writing = false
  if not ok then
    Logging.error("state_write_failed", { error = "internal" })
    return previous_hash, false, "internal"
  end
  if write_ok == false and err then
    Logging.error("state_write_failed", { error = tostring(err) })
  end
  return new_hash, write_ok, err
end

--- Debounced writer: bursts of flush() calls within interval_ms produce a
--- single write. later_fn(cb, ms) schedules the delayed write (injectable).
function Persistence.create_flusher(interval_ms, later_fn)
  local interval = tonumber(interval_ms) or 2000
  local schedule = later_fn or function(cb)
    cb()
  end
  local pending = nil
  local scheduled = false
  local last_write = 0
  local last_hash = nil

  local function do_write()
    scheduled = false
    if pending == nil then
      return
    end
    local state = pending
    pending = nil
    last_write = Persistence._now()
    local new_hash = Persistence.write_if_changed(state, last_hash)
    last_hash = new_hash
  end

  return function(state)
    pending = state
    local now = Persistence._now()
    if scheduled then
      return
    end
    if (now - last_write) >= interval then
      do_write()
    else
      scheduled = true
      schedule(do_write, interval - (now - last_write))
    end
  end, function()
    return last_hash
  end
end

--- Test helper: reports whether a write is in progress (always false
--- outside a write call; the lock itself is what matters).
function Persistence._is_writing()
  return writing
end

return Persistence
