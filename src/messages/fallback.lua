local Fallback = {}

function Fallback.unknown(renderer_name, action_name, extracted)
  return {
    kind = "unknown_event",
    renderer = renderer_name,
    action = action_name,
    extracted = extracted or {}
  }
end

return Fallback
