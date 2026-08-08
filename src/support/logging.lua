local RateLimit = require("src.support.rate_limit")
local Health = require("src.support.health")

local Logging = {}

local LEVEL = {
  error = 1,
  warning = 2,
  info = 3,
  debug = 4
}

local C2_LEVEL_NAMES = {
  error = "Critical",
  warning = "Warning",
  info = "Info",
  debug = "Debug"
}

local SENSITIVE_PATTERNS = {
  "continuation", "cookie", "token", "key", "authorization",
  "header", "payload", "password", "secret"
}

local DEDUPE_WINDOW_MS = 60000
local DEDUPE_MAX_EMITS = 3

local state = {
  level = "info",
  debug_enabled = false
}

-- Injectable sink for anonymized unknown-renderer samples (diagnostic mode).
-- Signature: fn(name, json_string). Default: no-op.
Logging._sample_sink = nil

local function is_sensitive_key(key)
  if type(key) ~= "string" then
    return false
  end
  local k = key:lower()
  for _, pattern in ipairs(SENSITIVE_PATTERNS) do
    if k:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

Logging.is_sensitive_key = is_sensitive_key

local function sanitize_value(key, value)
  if is_sensitive_key(key) then
    return "<redacted>"
  end
  if type(value) == "string" and #value > 160 then
    return value:sub(1, 160) .. "..."
  end
  if type(value) == "table" then
    return "<table>"
  end
  return value
end

local function sanitize_fields(fields)
  if type(fields) ~= "table" then
    return {}
  end
  local out = {}
  for key, value in pairs(fields) do
    out[key] = sanitize_value(key, value)
  end
  return out
end

--- Recursively redact sensitive keys from a decoded table (deep copy).
--- Used before persisting diagnostic samples.
function Logging.redact_deep(value, depth)
  if type(value) ~= "table" then
    return value
  end
  if (depth or 0) > 8 then
    return "<max-depth>"
  end
  local out = {}
  for key, item in pairs(value) do
    if is_sensitive_key(tostring(key)) then
      out[key] = "<redacted>"
    elseif type(item) == "table" then
      out[key] = Logging.redact_deep(item, (depth or 0) + 1)
    else
      out[key] = item
    end
  end
  return out
end

local function should_log(level)
  if level == "debug" and not state.debug_enabled then
    return false
  end
  local current = LEVEL[state.level] or LEVEL.info
  local asked = LEVEL[level] or LEVEL.info
  return asked <= current
end

local function c2_level(level)
  local c2 = rawget(_G, "c2")
  if type(c2) ~= "table" or type(c2.log) ~= "function" or type(c2.LogLevel) ~= "table" then
    return nil
  end
  return c2.LogLevel[C2_LEVEL_NAMES[level] or "Info"]
end

local function emit_line(level, line)
  local c2lvl = c2_level(level)
  if c2lvl ~= nil then
    local ok = pcall(rawget(_G, "c2").log, c2lvl, line)
    if ok then
      return
    end
  end
  print(line)
end

local function build_line(level, message, fields)
  local payload = sanitize_fields(fields)
  local parts = {}
  for k, v in pairs(payload) do
    table.insert(parts, tostring(k) .. "=" .. tostring(v))
  end
  table.sort(parts)
  local line = "[yt-chat][" .. level .. "] " .. tostring(message)
  if #parts > 0 then
    line = line .. " | " .. table.concat(parts, " ")
  end
  return line
end

-- Deduplication state for identical (level, message) lines, bounded.
local dedupe = {}

local function dedupe_decision(key)
  local now = RateLimit._now()
  local entry = dedupe[key]
  if not entry or (now - entry.start) > DEDUPE_WINDOW_MS then
    local size = 0
    for _ in pairs(dedupe) do
      size = size + 1
    end
    if size > 512 then
      dedupe = {}
    end
    dedupe[key] = { count = 1, start = now, summarized = false }
    return "emit"
  end
  entry.count = entry.count + 1
  if entry.count <= DEDUPE_MAX_EMITS then
    return "emit"
  end
  if not entry.summarized then
    entry.summarized = true
    return "summary"
  end
  return "drop"
end

local function emit(level, message, fields)
  if not should_log(level) then
    return
  end
  -- Deduplicate storms of identical lines: allow a few per window, emit
  -- one suppression summary, then drop until the window resets.
  local decision = dedupe_decision(level .. ":" .. tostring(message))
  if decision == "drop" then
    return
  end
  if decision == "summary" then
    emit_line(level, "[yt-chat][" .. level .. "] suppressed repeated logs for: " .. tostring(message))
    return
  end
  emit_line(level, build_line(level, message, fields))
end

function Logging.set_level(level)
  if LEVEL[level] ~= nil then
    state.level = level
  end
end

function Logging.set_debug(enabled)
  state.debug_enabled = enabled == true
end

function Logging.error(message, fields)
  emit("error", message, fields)
end

function Logging.warning(message, fields)
  emit("warning", message, fields)
end

function Logging.info(message, fields)
  emit("info", message, fields)
end

function Logging.debug(message, fields)
  emit("debug", message, fields)
end

function Logging.rate_limited(level, key, window_ms, max_hits, message, fields)
  if RateLimit.allow(key, window_ms, max_hits) then
    emit(level, message, fields)
  end
end

function Logging.redact_table(fields)
  return sanitize_fields(fields)
end

--- Record an anonymized sample of an unknown renderer/action.
--- Always rate-limited; the sink only fires in debug mode.
function Logging.sample(name, renderer_table)
  local safe_name = tostring(name or "unknown"):sub(1, 80)
  Health.increment("unknown_events")
  if not RateLimit.allow("sample:" .. safe_name, 60000, 1) then
    return
  end
  emit("warning", "unknown_event", { renderer = safe_name })
  if not state.debug_enabled or type(Logging._sample_sink) ~= "function" then
    return
  end
  local ok, json = pcall(require, "libs/json")
  if not ok then
    return
  end
  local redacted = Logging.redact_deep(renderer_table)
  local encode_ok, encoded = pcall(json.encode, redacted)
  if encode_ok and type(encoded) == "string" then
    Logging._sample_sink(safe_name, encoded:sub(1, 8000))
  end
end

return Logging
