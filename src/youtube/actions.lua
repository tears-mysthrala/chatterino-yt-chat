local Renderers = require("src.youtube.renderers")
local Moderation = require("src.messages.moderation")
local System = require("src.messages.system")
local Fallback = require("src.messages.fallback")

local Actions = {}

local function first_key(tbl)
  for k, _ in pairs(tbl or {}) do
    return k
  end
  return nil
end

local handlers = {}

handlers.addChatItemAction = function(action)
  return Renderers.from_item(action.item, "addChatItemAction")
end

handlers.addLiveChatTickerItemAction = function(action)
  return Renderers.from_item(action.item, "addLiveChatTickerItemAction")
end

handlers.replaceChatItemAction = function(action)
  return Renderers.from_item(action.replacementItem, "replaceChatItemAction")
end

handlers.markChatItemAsDeletedAction = function(action)
  return Moderation.deleted(action.deletedStateMessage and action.deletedStateMessage.message and
      action.deletedStateMessage.message.runs and action.deletedStateMessage.message.runs[1] and
      action.deletedStateMessage.message.runs[1].text or action.targetItemId, nil)
end

handlers.markChatItemsByAuthorAsDeletedAction = function(action)
  return Moderation.ban(action.externalChannelId)
end

handlers.removeChatItemAction = function(action)
  return System.event("remove_chat_item", "Removed chat item", { targetItemId = action.targetItemId })
end

handlers.addBannerToLiveChatCommand = function(action)
  return Renderers.from_item(action.bannerRenderer and action.bannerRenderer.liveChatBannerRenderer and
      action.bannerRenderer.liveChatBannerRenderer.contents, "addBannerToLiveChatCommand")
end

handlers.removeBannerForLiveChatCommand = function()
  return System.event("pin_removed", "Pinned message removed")
end

handlers.updateLiveChatPollAction = function(action)
  return System.event("poll_update", "Poll updated", { pollToUpdate = action.pollToUpdate and action.pollToUpdate.pollId })
end

handlers.replayChatItemAction = function(action)
  return handlers.addChatItemAction(action.actions and action.actions[1] or {})
end

function Actions.from_action(action)
  local name = first_key(action)
  if not name then
    return nil
  end
  local payload = action[name]
  local fn = handlers[name]
  if fn then
    return fn(payload or {})
  end
  return Fallback.unknown(nil, name, {})
end

return Actions
