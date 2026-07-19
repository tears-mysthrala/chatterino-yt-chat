local Text = require("src.messages.text")
local Emotes = require("src.messages.emotes")
local Monetary = require("src.messages.monetary")
local Memberships = require("src.messages.memberships")
local Polls = require("src.messages.polls")
local Fallback = require("src.messages.fallback")

local Renderers = {}

local function first_key(tbl)
  for k, _ in pairs(tbl or {}) do
    return k
  end
  return nil
end

local function extract_generic(renderer)
  local author = renderer.authorName and (renderer.authorName.simpleText or renderer.authorName.text) or nil
  local text = renderer.message and renderer.message.simpleText or nil
  local timestamp = renderer.timestampUsec
  return {
    author = author,
    text = text,
    timestamp_usec = timestamp
  }
end

function Renderers.from_item(item, action_name)
  if type(item) ~= "table" then
    return nil
  end
  if item.liveChatTextMessageRenderer then
    return Text.from_text_renderer(item.liveChatTextMessageRenderer)
  end
  if item.liveChatPaidMessageRenderer then
    return Monetary.super_chat(item.liveChatPaidMessageRenderer)
  end
  if item.liveChatPaidStickerRenderer then
    return Emotes.describe_sticker(item.liveChatPaidStickerRenderer)
  end
  if item.liveChatMembershipItemRenderer then
    return Memberships.from_renderer(item.liveChatMembershipItemRenderer)
  end
  if item.liveChatPlaceholderItemRenderer then
    return { kind = "placeholder", message_id = item.liveChatPlaceholderItemRenderer.id }
  end
  if item.liveChatPollRenderer then
    return Polls.from_renderer(item.liveChatPollRenderer)
  end
  local name = first_key(item)
  local renderer = item[name] or {}
  return Fallback.unknown(name, action_name, extract_generic(renderer))
end

return Renderers
