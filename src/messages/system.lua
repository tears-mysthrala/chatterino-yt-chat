local Common = require("src.messages.common")
local Emotes = require("src.messages.emotes")

local System = {}

--- Generic visible system event.
function System.event(kind, text, extra)
  local event = {
    kind = kind or "system",
    system_text = Common.safe_text(text, 300) or "system event"
  }
  if type(extra) == "table" then
    for k, v in pairs(extra) do
      event[k] = v
    end
  end
  return event
end

--- liveChatViewerEngagementMessageRenderer -> system event.
--- icon YOUTUBE_ROUND: YouTube system/engagement notes (e.g.
--- subscribers-only notices). icon POLL is handled by polls.lua.
function System.viewer_engagement(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local _, flat = Emotes.parse_runs(renderer.message)
  return {
    kind = "system",
    id = Common.safe_id(renderer.id),
    timestamp_usec = Common.timestamp_usec(renderer.timestampUsec),
    system_text = Common.safe_text(flat, 300) or "YouTube system message",
    source_renderer = "liveChatViewerEngagementMessageRenderer"
  }
end

--- liveChatModeChangeMessageRenderer -> mode_change event.
--- Text examples: "Slow mode is on", "Members-only mode is on",
--- "Subscribers-only mode is off".
function System.mode_change(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local text = Common.runs_flat(renderer.text) or ""
  local description = Common.runs_flat(renderer.subtext)
  local mode = "unknown"
  if text:find("Slow mode", 1, true) then
    mode = "slow"
  elseif text:find("Members-only", 1, true) then
    mode = "members_only"
  elseif text:find("subscribers%-only") or text:find("Subscribers%-only") then
    mode = "subscribers_only"
  end
  local enabled = text:find("is on", 1, true) ~= nil or text:find("turned on", 1, true) ~= nil
  return {
    kind = "mode_change",
    id = Common.safe_id(renderer.id),
    timestamp_usec = Common.timestamp_usec(renderer.timestampUsec),
    mode = { name = mode, enabled = enabled },
    system_text = Common.safe_text(text, 200) or "Chat mode changed",
    sub_text = Common.safe_text(description, 300),
    source_renderer = "liveChatModeChangeMessageRenderer"
  }
end

--- addBannerToLiveChatCommand -> pinned event. The banner contents embed a
--- full message renderer; its parsed event rides along for display.
function System.pinned(action, content_event, banner_renderer)
  if type(action) ~= "table" then
    return nil
  end
  local header_text = nil
  local header = banner_renderer and banner_renderer.header or nil
  if type(header) == "table" and type(header.liveChatBannerHeaderRenderer) == "table" then
    header_text = Common.runs_flat(header.liveChatBannerHeaderRenderer.text)
  end
  local target = Common.safe_id(banner_renderer and banner_renderer.targetId)
  return {
    kind = "pinned",
    -- "pin-" prefix: the pinned notice dedupes separately from the original
    -- message carrying the same YouTube id (no double rendering).
    id = target and ("pin-" .. target) or (content_event and content_event.id and ("pin-" .. content_event.id)) or nil,
    target_message_id = Common.safe_id(banner_renderer and banner_renderer.targetId),
    header_text = Common.safe_text(header_text, 200) or "Pinned message",
    pinned_message = content_event,
    source_action = "addBannerToLiveChatCommand"
  }
end

--- removeBannerForLiveChatCommand -> pin_removed event.
function System.pin_removed(action)
  if type(action) ~= "table" then
    return nil
  end
  return {
    kind = "pin_removed",
    target_message_id = Common.safe_id(action.targetActionId),
    system_text = "Pinned message removed",
    source_action = "removeBannerForLiveChatCommand"
  }
end

--- showLiveChatTooltipCommand -> system event with the tooltip text.
function System.tooltip(action)
  local renderer = type(action) == "table" and action.tooltip and action.tooltip.tooltipRenderer or nil
  if not renderer then
    return nil
  end
  local _, flat = Emotes.parse_runs(renderer.detailsText)
  return {
    kind = "system",
    system_text = Common.safe_text(flat, 300) or "YouTube notice",
    source_action = "showLiveChatTooltipCommand"
  }
end

--- liveChatTicker* renderers -> ticker events (ephemeral summaries of paid
--- messages / memberships shown in the ticker bar).
function System.ticker_paid(renderer, duration_sec)
  if type(renderer) ~= "table" then
    return nil
  end
  local Monetary = require("src.messages.monetary")
  local endpoint = type(renderer.showItemEndpoint) == "table" and
      renderer.showItemEndpoint.showLiveChatItemEndpoint or nil
  local full = nil
  if endpoint and type(endpoint.renderer) == "table" and endpoint.renderer.liveChatPaidMessageRenderer then
    full = Monetary.super_chat(endpoint.renderer.liveChatPaidMessageRenderer)
  end
  local event = {
    kind = "ticker_paid",
    id = Common.safe_id(renderer.id),
    author_channel_id = Common.safe_id(renderer.authorExternalChannelId),
    amount = Common.safe_text(Common.simple_text(renderer.amount), 60),
    ticker = {
      kind = "paid",
      duration_sec = tonumber(duration_sec) or tonumber(renderer.fullDurationSec) or nil
    },
    highlight_color = Common.argb_to_hex(renderer.endBackgroundColor),
    detail = full
  }
  event.amount = event.amount or (full and full.amount) or nil
  event.author = full and full.author or "[Super Chat]"
  event.text = full and full.text or ""
  return event
end

function System.ticker_sticker(renderer, duration_sec)
  if type(renderer) ~= "table" then
    return nil
  end
  local Monetary = require("src.messages.monetary")
  local endpoint = type(renderer.showItemEndpoint) == "table" and
      renderer.showItemEndpoint.showLiveChatItemEndpoint or nil
  local full = nil
  if endpoint and type(endpoint.renderer) == "table" and endpoint.renderer.liveChatPaidStickerRenderer then
    full = Monetary.super_sticker(endpoint.renderer.liveChatPaidStickerRenderer)
  end
  local pack = nil
  if type(renderer.tickerThumbnails) == "table" and type(renderer.tickerThumbnails[1]) == "table" then
    pack = Common.accessibility_label(renderer.tickerThumbnails[1])
  end
  return {
    kind = "ticker_sticker",
    id = Common.safe_id(renderer.id),
    author = full and full.author or "[Super Sticker]",
    amount = full and full.amount or nil,
    sticker = full and full.sticker or { alt = Common.safe_text(pack, 120) },
    ticker = { kind = "sticker", duration_sec = tonumber(duration_sec) or tonumber(renderer.fullDurationSec) or nil },
    detail = full
  }
end

function System.ticker_member(renderer, duration_sec)
  if type(renderer) ~= "table" then
    return nil
  end
  local Memberships = require("src.messages.memberships")
  local endpoint = type(renderer.showItemEndpoint) == "table" and
      renderer.showItemEndpoint.showLiveChatItemEndpoint or nil
  local full = nil
  if endpoint and type(endpoint.renderer) == "table" then
    if endpoint.renderer.liveChatMembershipItemRenderer then
      full = Memberships.from_renderer(endpoint.renderer.liveChatMembershipItemRenderer)
    elseif endpoint.renderer.liveChatSponsorshipsGiftPurchaseAnnouncementRenderer then
      full = Memberships.gift_purchase(endpoint.renderer.liveChatSponsorshipsGiftPurchaseAnnouncementRenderer)
    end
  end
  local detail_text = Common.simple_text(renderer.detailText) or Common.runs_flat(renderer.detailText)
  return {
    kind = "ticker_member",
    id = Common.safe_id(renderer.id),
    author = full and full.author or "[Member]",
    ticker = {
      kind = "member",
      duration_sec = tonumber(duration_sec) or tonumber(renderer.fullDurationSec) or nil,
      detail_text = Common.safe_text(detail_text, 120)
    },
    membership_kind = full and full.membership_kind or nil,
    gift_count = full and full.gift_count or nil,
    detail = full
  }
end

return System
