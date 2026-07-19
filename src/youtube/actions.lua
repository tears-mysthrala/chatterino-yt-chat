local Renderers = require("src.youtube.renderers")
local Moderation = require("src.messages.moderation")
local Polls = require("src.messages.polls")
local System = require("src.messages.system")
local Fallback = require("src.messages.fallback")
local Logging = require("src.support.logging")

local Actions = {}

local SKIP_KEYS = { clickTrackingParams = true, trackingParams = true }

local function skippable(key)
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

local function single(event)
  if event then
    return { event }
  end
  return {}
end

-- Known command that carries moderator UI state only (not a chat-visible
-- event); intentionally a no-op, documented in COMPATIBILITY.md.
local IGNORED_ACTIONS = {
  liveChatReportModerationStateCommand = true
}

local handlers = {}

handlers.addChatItemAction = function(action)
  return single(Renderers.from_item(action.item, "addChatItemAction"))
end

handlers.addLiveChatTickerItemAction = function(action)
  local item = action.item
  if type(item) ~= "table" then
    return {}
  end
  local duration = action.durationSec
  if item.liveChatTickerPaidMessageItemRenderer then
    return single(System.ticker_paid(item.liveChatTickerPaidMessageItemRenderer, duration))
  end
  if item.liveChatTickerPaidStickerItemRenderer then
    return single(System.ticker_sticker(item.liveChatTickerPaidStickerItemRenderer, duration))
  end
  if item.liveChatTickerSponsorItemRenderer then
    return single(System.ticker_member(item.liveChatTickerSponsorItemRenderer, duration))
  end
  return single(Fallback.unknown(first_key(item), "addLiveChatTickerItemAction", item[first_key(item)]))
end

handlers.replaceChatItemAction = function(action)
  local replacement = Renderers.from_item(action.replacementItem, "replaceChatItemAction")
  return single(Moderation.replaced(action, replacement))
end

handlers.markChatItemAsDeletedAction = function(action)
  return single(Moderation.deleted(action))
end

handlers.markChatItemsByAuthorAsDeletedAction = function(action)
  return single(Moderation.author_deleted(action, "markChatItemsByAuthorAsDeletedAction"))
end

handlers.removeChatItemByAuthorAction = function(action)
  return single(Moderation.author_deleted(action, "removeChatItemByAuthorAction"))
end

handlers.removeChatItemAction = function(action)
  return single(Moderation.removed(action))
end

handlers.addBannerToLiveChatCommand = function(action)
  local banner = type(action.bannerRenderer) == "table" and action.bannerRenderer.liveChatBannerRenderer or nil
  if not banner then
    return single(Fallback.unknown("liveChatBannerRenderer", "addBannerToLiveChatCommand", action.bannerRenderer))
  end
  local content_event = Renderers.from_item(banner.contents, "addBannerToLiveChatCommand")
  return single(System.pinned(action, content_event, banner))
end

handlers.removeBannerForLiveChatCommand = function(action)
  return single(System.pin_removed(action))
end

handlers.updateLiveChatPollAction = function(action)
  return single(Polls.update(action))
end

handlers.showLiveChatActionPanelAction = function(action)
  local event = Polls.from_action_panel(action)
  if event then
    return { event }
  end
  return single(Fallback.unknown("liveChatActionPanelRenderer", "showLiveChatActionPanelAction",
    action.panelToShow))
end

handlers.closeLiveChatActionPanelAction = function(action)
  return single(Polls.closed(action))
end

handlers.showLiveChatTooltipCommand = function(action)
  return single(System.tooltip(action))
end

handlers.replayChatItemAction = function(action)
  local events = {}
  if type(action.actions) == "table" then
    for _, nested in ipairs(action.actions) do
      for _, event in ipairs(Actions.from_action(nested)) do
        events[#events + 1] = event
      end
    end
  end
  return events
end

--- Parses one continuation action into a list of normalized events.
--- Unknown actions become visible fallback events; known UI-only commands
--- are documented no-ops. Never throws.
function Actions.from_action(action)
  if type(action) ~= "table" then
    return {}
  end
  local name = first_key(action)
  if not name then
    return {}
  end
  if IGNORED_ACTIONS[name] then
    Logging.debug("ignored_action", { action = name })
    return {}
  end
  local payload = action[name]
  local handler = handlers[name]
  if not handler then
    return single(Fallback.unknown(name, name, payload))
  end
  local ok, events = pcall(handler, type(payload) == "table" and payload or {})
  if ok and type(events) == "table" then
    return events
  end
  return single(Fallback.unknown(name, name, payload))
end

return Actions
