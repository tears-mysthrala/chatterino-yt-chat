local Emotes = {}

function Emotes.describe_emoji(emoji)
  if type(emoji) ~= "table" then
    return nil
  end
  return {
    id = emoji.emojiId,
    shortcuts = emoji.shortcuts or {},
    search_terms = emoji.searchTerms or {},
    image = emoji.image and emoji.image.thumbnails and emoji.image.thumbnails[1] or nil,
    custom = emoji.isCustomEmoji == true
  }
end

function Emotes.describe_sticker(sticker_renderer)
  local purchase = sticker_renderer.purchaseAmountText and
      (sticker_renderer.purchaseAmountText.simpleText or sticker_renderer.purchaseAmountText.text) or nil
  local author = sticker_renderer.authorName and (sticker_renderer.authorName.simpleText or sticker_renderer.authorName.text)
  return {
    kind = "super_sticker",
    message_id = sticker_renderer.id,
    author = author,
    amount = purchase,
    sticker = sticker_renderer.sticker and sticker_renderer.sticker.thumbnails and sticker_renderer.sticker.thumbnails[1] or nil
  }
end

return Emotes
