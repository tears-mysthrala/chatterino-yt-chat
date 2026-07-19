local Monetary = {}

local function amount_text(node)
  if type(node) ~= "table" then
    return nil
  end
  return node.simpleText or node.text
end

function Monetary.super_chat(renderer)
  return {
    kind = "super_chat",
    message_id = renderer.id,
    author = renderer.authorName and (renderer.authorName.simpleText or renderer.authorName.text),
    amount = amount_text(renderer.purchaseAmountText),
    text = renderer.message and renderer.message.runs and renderer.message.runs[1] and renderer.message.runs[1].text or "",
    color = renderer.bodyBackgroundColor,
    badges = renderer.authorBadges or {}
  }
end

function Monetary.membership_milestone(renderer)
  return {
    kind = "membership",
    message_id = renderer.id,
    author = renderer.authorName and (renderer.authorName.simpleText or renderer.authorName.text),
    header = amount_text(renderer.headerSubtext) or amount_text(renderer.headerPrimaryText),
    text = renderer.message and renderer.message.runs and renderer.message.runs[1] and renderer.message.runs[1].text or "",
    badges = renderer.authorBadges or {}
  }
end

return Monetary
