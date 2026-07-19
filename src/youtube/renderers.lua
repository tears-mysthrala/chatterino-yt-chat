local Text = require("src.messages.text")
local Monetary = require("src.messages.monetary")
local Memberships = require("src.messages.memberships")
local Polls = require("src.messages.polls")
local System = require("src.messages.system")
local Fallback = require("src.messages.fallback")
local Common = require("src.messages.common")

local Renderers = {}

local SKIP_KEYS = { clickTrackingParams = true, trackingParams = true }

local function skippable(key)
  if type(key) ~= "string" then
    return true
  end
  return SKIP_KEYS[key] == true or key:sub(1, 1) == "_"
end

local function first_key(tbl)
  for k, _ in pairs(tbl or {}) do
    if not skippable(k) then
      return k
    end
  end
  return nil
end

local function viewer_engagement(renderer)
  local icon = type(renderer.icon) == "table" and renderer.icon.iconType or nil
  if icon == "POLL" then
    return Polls.from_engagement(renderer)
  end
  return System.viewer_engagement(renderer)
end

local HANDLERS = {
  liveChatTextMessageRenderer = Text.from_text_renderer,
  liveChatPaidMessageRenderer = Monetary.super_chat,
  liveChatPaidStickerRenderer = Monetary.super_sticker,
  liveChatMembershipItemRenderer = Memberships.from_renderer,
  liveChatSponsorshipsGiftPurchaseAnnouncementRenderer = Memberships.gift_purchase,
  liveChatSponsorshipsGiftRedemptionAnnouncementRenderer = Memberships.gift_redemption,
  liveChatViewerEngagementMessageRenderer = viewer_engagement,
  liveChatModeChangeMessageRenderer = System.mode_change,
  liveChatDonationAnnouncementRenderer = Monetary.donation,
  liveChatLegacyPaidMessageRenderer = Monetary.legacy_paid,
  liveChatPlaceholderItemRenderer = function(renderer)
    return {
      kind = "placeholder",
      id = Common.safe_id(renderer.id),
      timestamp_usec = Common.timestamp_usec(renderer.timestampUsec)
    }
  end
}

Renderers.HANDLERS = HANDLERS

--- Dispatches an item payload ({<rendererName>: {...}}) to its handler.
--- Always returns an event; unknown renderers become visible fallback
--- events instead of being dropped.
function Renderers.from_item(item, action_name)
  if type(item) ~= "table" then
    return nil
  end
  local name = first_key(item)
  if not name then
    return nil
  end
  local renderer = item[name]
  local handler = HANDLERS[name]
  if handler then
    local ok, event = pcall(handler, renderer or {})
    if ok and event then
      event.source_renderer = event.source_renderer or name
      return event
    end
  end
  return Fallback.unknown(name, action_name, renderer)
end

return Renderers
