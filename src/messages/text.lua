local Common = require("src.messages.common")
local Emotes = require("src.messages.emotes")
local Badges = require("src.messages.badges")
local Logging = require("src.support.logging")

local Text = {}

--- Shared author extraction for any renderer carrying author fields.
function Text.parse_author(renderer)
  local author = Common.safe_text(Common.simple_text(renderer.authorName), 200)
  if not author or author == "" then
    -- Paid stickers and some events omit authorName; the author photo
    -- accessibility label often carries the name instead.
    author = Common.safe_text(Common.accessibility_label(renderer.authorPhoto), 200)
  end
  local badges, roles = Badges.parse(renderer.authorBadges)
  return {
    author = author,
    author_channel_id = Common.safe_id(renderer.authorExternalChannelId),
    author_photo = Common.thumbnail_url(renderer.authorPhoto),
    badges = badges,
    roles = roles
  }
end

local function base_event(renderer, kind)
  local event = Text.parse_author(renderer)
  event.kind = kind
  event.id = Common.safe_id(renderer.id)
  event.timestamp_usec = Common.timestamp_usec(renderer.timestampUsec)
  return event
end

Text.base_event = base_event

--- liveChatTextMessageRenderer -> text_message event.
function Text.from_text_renderer(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = base_event(renderer, "text_message")
  local runs, flat, unknown = Emotes.parse_runs(renderer.message)
  event.runs = runs
  event.text = Common.safe_text(flat) or ""
  if unknown > 0 then
    Logging.rate_limited("warning", "unknown-runs", 60000, 1, "unknown_runs_in_message",
      { count = unknown })
  end
  if not event.author then
    event.author = "[YouTube chatter]"
  end
  return event
end

return Text
