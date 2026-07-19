local Common = require("src.messages.common")
local Text = require("src.messages.text")
local Emotes = require("src.messages.emotes")

local Monetary = {}

--- liveChatPaidMessageRenderer -> super_chat event.
--- Amounts are kept verbatim (YouTube's own string); no currency math.
function Monetary.super_chat(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "super_chat")
  event.amount = Common.safe_text(Common.simple_text(renderer.purchaseAmountText), 60)
  local runs, flat = Emotes.parse_runs(renderer.message)
  event.runs = runs
  event.text = Common.safe_text(flat) or ""
  event.colors = {
    header_background = Common.argb_to_hex(renderer.headerBackgroundColor),
    header_text = Common.argb_to_hex(renderer.headerTextColor),
    body_background = Common.argb_to_hex(renderer.bodyBackgroundColor),
    body_text = Common.argb_to_hex(renderer.bodyTextColor),
    author_name = Common.argb_to_hex(renderer.authorNameTextColor)
  }
  event.highlight_color = event.colors.body_background
  if not event.author then
    event.author = "[Super Chat]"
  end
  return event
end

--- liveChatPaidStickerRenderer -> super_sticker event.
function Monetary.super_sticker(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "super_sticker")
  event.amount = Common.safe_text(Common.simple_text(renderer.purchaseAmountText), 60)
  event.sticker = {
    alt = Common.safe_text(Common.accessibility_label(renderer.sticker), 120),
    url = Common.thumbnail_url(renderer.sticker)
  }
  event.colors = {
    background = Common.argb_to_hex(renderer.backgroundColor),
    chip_text = Common.argb_to_hex(renderer.moneyChipTextColor),
    chip_background = Common.argb_to_hex(renderer.moneyChipBackgroundColor)
  }
  event.highlight_color = event.colors.background
  event.text = ""
  if not event.author then
    event.author = "[Super Sticker]"
  end
  return event
end

--- liveChatDonationAnnouncementRenderer -> donation event (kind super_chat
--- family; kept separate for the matrix).
function Monetary.donation(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "donation")
  event.amount = Common.safe_text(Common.simple_text(renderer.donationAmountText), 60)
  local runs, flat = Emotes.parse_runs(renderer.subtext)
  event.runs = runs
  event.text = Common.safe_text(flat) or ""
  if not event.author then
    event.author = "[Donation]"
  end
  return event
end

--- liveChatLegacyPaidMessageRenderer -> legacy membership/paid event.
function Monetary.legacy_paid(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "legacy_paid")
  event.amount = Common.safe_text(Common.simple_text(renderer.purchaseAmountText), 60)
  local runs, flat = Emotes.parse_runs(renderer.message or renderer.headerSubtext)
  event.runs = runs
  event.text = Common.safe_text(flat) or ""
  event.header_text = Common.safe_text(Common.runs_flat(renderer.headerPrimaryText), 200)
  event.highlight_color = Common.argb_to_hex(renderer.headerBackgroundColor)
  if not event.author then
    event.author = "[Member]"
  end
  return event
end

return Monetary
