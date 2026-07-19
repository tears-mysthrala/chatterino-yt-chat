local System = {}

function System.event(kind, text, fields)
  return {
    kind = kind or "system",
    text = text or "",
    fields = fields or {}
  }
end

return System
