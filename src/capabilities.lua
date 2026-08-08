local Capabilities = {}

function Capabilities.detect()
  local c2 = rawget(_G, "c2")
  local image_flags = type(c2) == "table" and type(c2.MessageElementFlag) == "table" and
      (c2.MessageElementFlag.AlwaysShow or c2.MessageElementFlag.EmoteImage) or nil
  return {
    settings_gui = false, -- Chatterino 2.5.5 exposes no plugin settings-page API.
    images = type(c2) == "table" and type(c2.Image) == "table" and
        type(c2.Image.from_url) == "function" and image_flags ~= nil,
    completions = type(c2) == "table" and type(c2.register_callback) == "function" and
        type(c2.EventType) == "table" and c2.EventType.CompletionRequested ~= nil
  }
end

return Capabilities
