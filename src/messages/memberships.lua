local Memberships = {}

local function simple_text(node)
  if type(node) ~= "table" then
    return nil
  end
  return node.simpleText or node.text
end

function Memberships.from_renderer(renderer)
  return {
    kind = "membership",
    message_id = renderer.id,
    author = renderer.authorName and simple_text(renderer.authorName),
    header = simple_text(renderer.headerPrimaryText) or simple_text(renderer.headerSubtext),
    text = renderer.message and renderer.message.runs and renderer.message.runs[1] and renderer.message.runs[1].text or "",
    badges = renderer.authorBadges or {},
    gifted_count = renderer.giftMembershipsCount
  }
end

return Memberships
