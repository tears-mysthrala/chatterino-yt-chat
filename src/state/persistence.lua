local json = require("libs/json")
local Migrations = require("src.state.migrations")
local Logging = require("src.support.logging")
local Clock = require("src.support.clock")

local Persistence = {}

local STATE_FILE = "YT_CHAT.json"
local BACKUP_SUFFIX = ".bak"
local TMP_SUFFIX = ".tmp"

-- Chatterino's sandbox has no `os` library: os.rename/os.remove do not
-- exist there. Atomic replace via rename is used when available (tests,
-- plain Lua); otherwise persistence degrades to tmp+verify+write with a
-- .bak safety copy (see docs/architecture.md).
local has_os_rename = type(os) == "table" and type(os.rename) == "function"
local has_os_remove = type(os) == "table" and type(os.remove) == "function"

-- Test hook: force the no-rename path.
Persistence._force_no_rename = false

local dir = "."
local writing = false

-- Set to "bak" or "default" when read() had to recover; nil on clean read.
Persistence.last_recovery = nil

-- Injectable wall clock (ms) for the debounce flusher.
Persistence._now = function()
  return Clock.now_ms()
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
      local number = tonumber(value) or default_value
      if key == "chat_sync_delay_ms" then
        number = math.floor(math.max(0, math.min(30000, number)))
      end
      out.settings[key] = number
    elseif type(default_value) == "string" then
      if key == "language" then
        out.settings[key] = value == "en" and "en" or "es"
      else
        out.settings[key] = type(value) == "string" and value or default_value
      end
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
      normalized.paused = entry.paused == true
      out.channels[key] = normalized
    end
  end
  return out
end

local function write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then
    return false, err
  end
  f:write(content)
  f:flush()
  f:close()
  return true, nil
end

function Persistence.export_snapshot(state)
  local encoded = json.encode(Persistence.validate_schema(state))
  return write_file(dir .. "/YT_CHAT.export.json", encoded)
end

function Persistence.export_diagnostics(snapshot)
  return write_file(dir .. "/YT_CHAT.diagnostics.json", json.encode(snapshot))
end

function Persistence.import_snapshot()
  local decoded = safe_decode(read_all(dir .. "/YT_CHAT.export.json"))
  if not decoded then
    return nil, "missing_or_invalid_export"
  end
  return Persistence.validate_schema(decoded), nil
end

local function backup_current(path)
  local existing = read_all(path)
  if existing then
    write_file(path .. BACKUP_SUFFIX, existing)
  end
end

local function restore_from_backup(path)
  local backup = read_all(path .. BACKUP_SUFFIX)
  if backup then
    write_file(path, backup)
  end
end

local function write_atomic(path, encoded)
  local tmp = path .. TMP_SUFFIX
  local ok, err = write_file(tmp, encoded)
  if not ok then
    return false, err
  end

  if has_os_rename and not Persistence._force_no_rename then
    backup_current(path)
    if has_os_remove then
      os.remove(path)
    end
    local renamed, rename_err = os.rename(tmp, path)
    if not renamed then
      restore_from_backup(path)
      os.remove(tmp)
      return false, rename_err
    end
    return true, nil
  end

  -- Sandbox path (no os.rename): verify the tmp copy, keep a .bak, then
  -- rewrite the real file and verify it. Not rename-atomic, but any
  -- interruption leaves either the old file, the .bak, or a detectably
  -- corrupt file that read() recovers from .bak.
  if read_all(tmp) ~= encoded then
    return false, "tmp_verify_failed"
  end
  backup_current(path)
  local wrote, write_err = write_file(path, encoded)
  if not wrote then
    restore_from_backup(path)
    return false, write_err
  end
  if read_all(path) ~= encoded then
    restore_from_backup(path)
    return false, "final_verify_failed"
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
