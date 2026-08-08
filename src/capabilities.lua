local Capabilities = {}

function Capabilities.detect()
  local c2 = rawget(_G, "c2")
  return {
    settings_gui = false, -- Chatterino 2.5.5 exposes no plugin settings-page API.
    images = type(c2) == "table" and type(c2.Image) == "table" and
        type(c2.Image.from_url) == "function",
    completions = type(c2) == "table" and type(c2.register_callback) == "function" and
        type(c2.EventType) == "table" and c2.EventType.CompletionRequested ~= nil
  }
end

return Capabilities
