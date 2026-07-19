local Badges = require("src.messages.badges")

local Builder = {}

local function text_element(text, color, style)
  return {
    type = "text",
    text = text,
    color = color,
    style = style
  }
end

local function event_to_text(event)
  local kind = event.kind
  if kind == "text" then
    return event.text
  end
  if kind == "super_chat" then
    return string.format("[Super Chat · %s] %s: %s", event.amount or "?", event.author or "User", event.text or "")
  end
  if kind == "super_sticker" then
    return string.format("[Super Sticker · %s] %s", event.amount or "?", event.author or "User")
  end
  if kind == "membership" then
    return string.format("[Membership] %s %s", event.author or "User", event.header or event.text or "")
  end
  if kind == "poll" then
    return string.format("[Poll] %s", event.question or "Poll update")
  end
  if kind == "moderation_deleted" then
    return string.format("[Moderation] message removed id=%s", event.target_message_id or "?")
  end
  if kind == "moderation_timeout" then
    return string.format("[Moderation] timeout user=%s duration=%s", event.author_channel_id or "?", tostring(event.duration_sec or "?"))
  end
  if kind == "moderation_hide_user" then
    return string.format("[Moderation] user hidden id=%s", event.author_channel_id or "?")
  end
  if kind == "unknown_event" then
    local action = event.action or "?"
    local renderer = event.renderer or "?"
    return string.format("[Unknown YouTube event] action=%s renderer=%s", action, renderer)
  end
  return event.text or "[System event]"
end

function Builder.to_chatterino_message(event, show_channel)
  local ts = tostring(event.timestamp_usec or os.time())
  local elements = {
    text_element("YT", "system", c2 and c2.FontStyle.ChatMediumBold or nil),
    { type = "timestamp", time = ts }
  }
  if show_channel and event.channel_name then
    table.insert(elements, text_element("(" .. event.channel_name .. ")", "system", c2 and c2.FontStyle.Tiny or nil))
  end
  local badges = Badges.collect(event.author_badges)
  if #badges > 0 then
    table.insert(elements, text_element("[" .. table.concat(badges, ",") .. "]", "system", c2 and c2.FontStyle.ChatMediumBold or nil))
  end
  if event.author then
    table.insert(elements, text_element(event.author .. ":", "text", c2 and c2.FontStyle.ChatMediumBold or nil))
  end
  table.insert(elements, text_element(event_to_text(event), "text", nil))

  if c2 and c2.Message and c2.Message.new then
    return c2.Message.new({
      id = "yt-chat-" .. tostring(event.message_id or event.target_message_id or ts),
      message_text = event_to_text(event),
      elements = elements
    })
  end
  return {
    id = "yt-chat-" .. tostring(event.message_id or event.target_message_id or ts),
    message_text = event_to_text(event),
    elements = elements
  }
end

return Builder
