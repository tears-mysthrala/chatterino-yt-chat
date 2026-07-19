local Common = require("src.messages.common")
local Logging = require("src.support.logging")

local Fallback = {}

--- Defensive extraction of anything recognizable from an unknown payload.
local function extract(payload)
  if type(payload) ~= "table" then
    return {}
  end
  local out = {}
  out.author = Common.safe_text(Common.simple_text(payload.authorName), 200)
  out.text = Common.safe_text(Common.runs_flat(payload.message), 300)
  out.amount = Common.safe_text(Common.simple_text(payload.purchaseAmountText), 60)
  out.timestamp_usec = Common.timestamp_usec(payload.timestampUsec)
  out.id = Common.safe_id(payload.id)
  return out
end

--- Unknown renderer/action -> visible, safe unknown_event. Never throws,
--- never logs full payloads in production; a redacted sample is available
--- through the diagnostic sink when debug mode is on.
function Fallback.unknown(renderer_name, action_name, payload)
  local name = Common.safe_text(renderer_name, 80) or "unknown"
  local extracted = extract(payload)
  Logging.sample(name, payload)
  local parts = { "Unsupported event: " .. name }
  if action_name and action_name ~= name then
    parts[#parts + 1] = "in " .. tostring(action_name)
  end
  if extracted.author then
    parts[#parts + 1] = "by " .. extracted.author
  end
  if extracted.amount then
    parts[#parts + 1] = "(" .. extracted.amount .. ")"
  end
  if extracted.text then
    parts[#parts + 1] = "— " .. extracted.text:sub(1, 120)
  end
  return {
    kind = "unknown_event",
    id = extracted.id,
    author = extracted.author,
    timestamp_usec = extracted.timestamp_usec,
    source_renderer = name,
    source_action = action_name,
    system_text = table.concat(parts, " ")
  }
end

return Fallback
