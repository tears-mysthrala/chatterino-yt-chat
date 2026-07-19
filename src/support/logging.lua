local RateLimit = require("src.support.rate_limit")

local Logging = {}

local LEVEL = {
  error = 1,
  warning = 2,
  info = 3,
  debug = 4
}

local state = {
  level = "info",
  debug_enabled = false
}

local function redact_value(key, value)
  if type(key) ~= "string" then
    return value
  end
  local k = key:lower()
  if k:find("continuation", 1, true) or k:find("cookie", 1, true) or k:find("token", 1, true) or k:find("key", 1, true) then
    return "<redacted>"
  end
  return value
end

local function sanitize_fields(fields)
  if type(fields) ~= "table" then
    return {}
  end
  local out = {}
  for key, value in pairs(fields) do
    local rv = redact_value(key, value)
    if type(rv) == "string" and #rv > 160 then
      out[key] = rv:sub(1, 160) .. "..."
    else
      out[key] = rv
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

local function emit(level, message, fields)
  if not should_log(level) then
    return
  end
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
  print(line)
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

return Logging
