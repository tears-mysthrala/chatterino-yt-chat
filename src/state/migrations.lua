local Migrations = {}

Migrations.SCHEMA_VERSION = 4

local DEFAULT_SETTINGS = {
  debug = false,
  offline_poll_schedule = { 30, 60, 120, 300 },
  offline_poll_max = 300,
  chat_poll_min_ms = 500,
  chat_poll_max_ms = 15000,
  chat_poll_fallback_ms = 1000,
  chat_sync_delay_ms = 0
}

local function default_settings()
  local out = {}
  for k, v in pairs(DEFAULT_SETTINGS) do
    if type(v) == "table" then
      local copy = {}
      for i, item in ipairs(v) do
        copy[i] = item
      end
      out[k] = copy
    else
      out[k] = v
    end
  end
  return out
end

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end
  local n = 0
  for k in pairs(value) do
    if type(k) ~= "number" then
      return false
    end
    n = n + 1
  end
  return n == #value
end

-- v0 (plugin original) -> v1: settings con defaults, debug normalizado.
local function migrate_to_v1(state)
  state.settings = type(state.settings) == "table" and state.settings or {}
  local defaults = default_settings()
  for k, v in pairs(defaults) do
    if state.settings[k] == nil then
      state.settings[k] = v
    end
  end
  state.settings.debug = state.settings.debug == true
  state.channels = type(state.channels) == "table" and state.channels or {}
  state.schema_version = 1
  return state
end

-- v1 -> v2: entradas de canal normalizadas (channel_id/handle/display_name,
-- splits como array de strings, claves estables channel_id o "handle:<h>").
local function migrate_to_v2(state)
  local normalized = {}
  for key, entry in pairs(state.channels or {}) do
    if type(entry) == "table" then
      local channel_id = type(entry.channel_id) == "string" and entry.channel_id or nil
      local handle = type(entry.handle) == "string" and entry.handle or nil
      if channel_id == nil and type(key) == "string" and key:match("^UC[%w_%-]+$") then
        channel_id = key
      end
      if handle == nil and type(key) == "string" and key:match("^handle:") then
        handle = key:sub(8)
      end
      local splits = {}
      if is_array(entry.splits) then
        for _, split in ipairs(entry.splits) do
          if type(split) == "string" and split ~= "" and #splits < 64 then
            splits[#splits + 1] = split
          end
        end
      end
      local new_key = channel_id or (handle and ("handle:" .. handle)) or tostring(key)
      normalized[new_key] = {
        channel_id = channel_id,
        handle = handle,
        display_name = type(entry.display_name) == "string" and entry.display_name or nil,
        splits = splits
      }
    end
  end
  state.channels = normalized
  state.schema_version = 2
  return state
end

-- v2 -> v3: optional extra delay added to YouTube's requested poll interval.
local function migrate_to_v3(state)
  state.settings = type(state.settings) == "table" and state.settings or {}
  local delay = tonumber(state.settings.chat_sync_delay_ms) or DEFAULT_SETTINGS.chat_sync_delay_ms
  state.settings.chat_sync_delay_ms = math.floor(math.max(0, math.min(30000, delay)))
  state.schema_version = 3
  return state
end

local function migrate_to_v4(state)
  state.settings = type(state.settings) == "table" and state.settings or {}
  for _, entry in pairs(state.channels or {}) do
    if type(entry) == "table" then
      entry.paused = entry.paused == true
    end
  end
  state.schema_version = 4
  return state
end

local STEPS = {
  [1] = migrate_to_v1,
  [2] = migrate_to_v2,
  [3] = migrate_to_v3,
  [4] = migrate_to_v4
}

--- Applies every pending migration in order. Idempotent and total:
--- garbage input yields a fresh default schema instead of an error.
function Migrations.upgrade(state)
  if type(state) ~= "table" then
    state = {}
  end
  local version = tonumber(state.schema_version) or 0
  local ok, result = pcall(function()
    local current = state
    while version < Migrations.SCHEMA_VERSION do
      version = version + 1
      local step = STEPS[version]
      if step then
        current = step(current)
      else
        current.schema_version = version
      end
    end
    return current
  end)
  if not ok or type(result) ~= "table" then
    return {
      schema_version = Migrations.SCHEMA_VERSION,
      settings = default_settings(),
      channels = {}
    }
  end
  return result
end

Migrations.default_settings = default_settings

return Migrations
