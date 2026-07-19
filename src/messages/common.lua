local Validation = require("src.support.validation")

-- Shared defensive helpers for renderer parsing.
local Common = {}

function Common.simple_text(container)
  if type(container) ~= "table" then
    return nil
  end
  if type(container.simpleText) == "string" then
    return container.simpleText
  end
  if type(container.text) == "string" then
    return container.text
  end
  return nil
end

--- Flattens runs into plain text when a simpleText field is absent.
function Common.runs_flat(container)
  if type(container) ~= "table" then
    return nil
  end
  local simple = Common.simple_text(container)
  if simple then
    return simple
  end
  if type(container.runs) ~= "table" then
    return nil
  end
  local parts = {}
  for _, run in ipairs(container.runs) do
    if type(run) == "table" and type(run.text) == "string" then
      parts[#parts + 1] = run.text
    end
  end
  if #parts == 0 then
    return nil
  end
  return table.concat(parts)
end

--- Last (highest resolution) thumbnail URL of a thumbnails container,
--- validated against the image allowlist.
function Common.thumbnail_url(container)
  if type(container) ~= "table" or type(container.thumbnails) ~= "table" then
    return nil
  end
  local last = nil
  for _, thumb in ipairs(container.thumbnails) do
    if type(thumb) == "table" and type(thumb.url) == "string" then
      last = thumb.url
    end
  end
  if last and Validation.is_safe_image_url(last) then
    return last
  end
  return nil
end

function Common.accessibility_label(container)
  if type(container) ~= "table" then
    return nil
  end
  local acc = container.accessibility
  if type(acc) ~= "table" then
    return nil
  end
  local data = acc.accessibilityData
  if type(data) ~= "table" then
    return nil
  end
  if type(data.label) == "string" then
    return data.label
  end
  return nil
end

function Common.timestamp_usec(value)
  local n = tonumber(value)
  if n == nil or n < 0 or n > 1e18 then
    return nil
  end
  return math.floor(n)
end

function Common.timestamp_ms(value)
  local usec = Common.timestamp_usec(value)
  if not usec then
    return nil
  end
  return math.floor(usec / 1000)
end

--- YouTube colors are ARGB integers. Returns "#rrggbb" or nil.
function Common.argb_to_hex(value)
  local n = tonumber(value)
  if n == nil or n < 0 or n > 0xFFFFFFFF then
    return nil
  end
  local r = math.floor(n / 65536) % 256
  local g = math.floor(n / 256) % 256
  local b = n % 256
  return string.format("#%02x%02x%02x", r, g, b)
end

function Common.safe_id(value)
  return Validation.sanitize_id(value, Validation.MAX_ID_LEN)
end

function Common.safe_text(value, max)
  local cleaned = Validation.sanitize_text(value, max or Validation.MAX_TEXT_LEN)
  if cleaned == "" then
    return nil
  end
  return cleaned
end

return Common
