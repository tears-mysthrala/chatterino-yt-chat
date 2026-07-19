local Common = require("src.messages.common")
local Emotes = require("src.messages.emotes")

local Moderation = {}

--- markChatItemAsDeletedAction -> deleted_message event.
function Moderation.deleted(action)
  if type(action) ~= "table" then
    return nil
  end
  local _, flat = Emotes.parse_runs(action.deletedStateMessage)
  return {
    kind = "deleted_message",
    target_message_id = Common.safe_id(action.targetItemId),
    system_text = Common.safe_text(flat, 200) or "Message deleted",
    source_action = "markChatItemAsDeletedAction"
  }
end

--- markChatItemsByAuthorAsDeletedAction / removeChatItemByAuthorAction ->
--- author_deleted event.
function Moderation.author_deleted(action, source_action)
  if type(action) ~= "table" then
    return nil
  end
  return {
    kind = "author_deleted",
    target_author_channel_id = Common.safe_id(action.externalChannelId),
    system_text = "Messages from a user were removed by moderation",
    source_action = source_action or "markChatItemsByAuthorAsDeletedAction"
  }
end

--- removeChatItemAction -> deleted_message event (no state message).
function Moderation.removed(action)
  if type(action) ~= "table" then
    return nil
  end
  return {
    kind = "deleted_message",
    target_message_id = Common.safe_id(action.targetItemId),
    system_text = "Message removed",
    source_action = "removeChatItemAction"
  }
end

--- replaceChatItemAction -> replaced_message event; the replacement event
--- itself is attached for the builder/adapter to deliver.
function Moderation.replaced(action, replacement_event)
  if type(action) ~= "table" then
    return nil
  end
  return {
    kind = "replaced_message",
    target_message_id = Common.safe_id(action.targetItemId),
    replacement = replacement_event,
    source_action = "replaceChatItemAction"
  }
end

return Moderation
