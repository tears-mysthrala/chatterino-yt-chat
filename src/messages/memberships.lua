local Common = require("src.messages.common")
local Text = require("src.messages.text")
local Emotes = require("src.messages.emotes")

local Memberships = {}

--- liveChatMembershipItemRenderer -> membership event.
--- Distinguishes new member (no message/empty body) from milestone
--- renewals (headerPrimaryText carries the tenure, message may follow).
function Memberships.from_renderer(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "membership")

  local is_milestone = renderer.empty ~= nil or renderer.message ~= nil
  if is_milestone then
    local duration_runs = {}
    local primary = renderer.headerPrimaryText
    if type(primary) == "table" and type(primary.runs) == "table" then
      for i, run in ipairs(primary.runs) do
        if i > 1 and type(run) == "table" and type(run.text) == "string" then
          duration_runs[#duration_runs + 1] = run.text
        end
      end
    end
    event.member_since = Common.safe_text(table.concat(duration_runs), 60)
    event.level = Common.safe_text(Common.runs_flat(renderer.headerSubtext), 120)
    local runs, flat = Emotes.parse_runs(renderer.message)
    event.runs = runs
    event.text = Common.safe_text(flat) or ""
    event.membership_kind = "milestone"
  else
    -- New member: headerSubtext is "New Member" or "Welcome <level>!".
    local sub_runs = type(renderer.headerSubtext) == "table" and renderer.headerSubtext.runs or nil
    local level = nil
    if type(sub_runs) == "table" and #sub_runs > 1 and type(sub_runs[2]) == "table" then
      level = sub_runs[2].text
    end
    event.level = Common.safe_text(level, 120)
    event.header_text = Common.safe_text(Common.runs_flat(renderer.headerSubtext), 200) or "New member"
    event.text = ""
    event.membership_kind = "new"
  end
  if not event.author then
    event.author = "[Member]"
  end
  return event
end

--- liveChatSponsorshipsGiftPurchaseAnnouncementRenderer -> membership_gift.
function Memberships.gift_purchase(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "membership_gift")
  local header = type(renderer.header) == "table" and renderer.header.liveChatSponsorshipsHeaderRenderer or nil
  if header then
    event.author = Common.safe_text(Common.simple_text(header.authorName), 200) or event.author
    local badges, roles = require("src.messages.badges").parse(header.authorBadges)
    event.badges = badges
    event.roles = roles
    -- primaryText runs: [prefix, count, middle, channelName]
    local primary = header.primaryText
    if type(primary) == "table" and type(primary.runs) == "table" then
      local count_run = primary.runs[2]
      if type(count_run) == "table" then
        event.gift_count = tonumber(count_run.text) or nil
      end
      event.header_text = Common.safe_text(Common.runs_flat(primary), 200)
    end
    event.author_photo = Common.thumbnail_url(header.authorPhoto)
  end
  event.gift_count = event.gift_count or 1
  if not event.author then
    event.author = "[Gift]"
  end
  return event
end

--- liveChatSponsorshipsGiftRedemptionAnnouncementRenderer ->
--- membership_gift_received.
function Memberships.gift_redemption(renderer)
  if type(renderer) ~= "table" then
    return nil
  end
  local event = Text.base_event(renderer, "membership_gift_received")
  local runs, flat = Emotes.parse_runs(renderer.message)
  event.runs = runs
  event.text = Common.safe_text(flat) or ""
  event.header_text = Common.safe_text(flat, 200)
  if not event.author then
    event.author = "[Gift received]"
  end
  return event
end

return Memberships
