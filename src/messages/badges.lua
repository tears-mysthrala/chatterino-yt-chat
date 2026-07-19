local Common = require("src.messages.common")

local Badges = {}

local ICON_ROLES = {
  OWNER = "owner",
  MODERATOR = "moderator",
  VERIFIED = "verified"
}

local function months_from_label(label)
  if type(label) ~= "string" then
    return nil
  end
  local months = label:match("(%d+)%s*month")
  if months then
    return tonumber(months)
  end
  local years = label:match("(%d+)%s*year")
  if years then
    return tonumber(years) * 12
  end
  return nil
end

--- Parses authorBadges[].liveChatAuthorBadgeRenderer into badge records and
--- role flags. Member badges carry a custom thumbnail + tooltip label.
function Badges.parse(author_badges)
  local badges = {}
  local roles = { owner = false, moderator = false, member = false, verified = false }
  if type(author_badges) ~= "table" then
    return badges, roles
  end
  for _, entry in ipairs(author_badges) do
    local badge = type(entry) == "table" and entry.liveChatAuthorBadgeRenderer or nil
    if badge then
      local label = Common.safe_text(badge.tooltip, 120)
      local icon_type = type(badge.icon) == "table" and badge.icon.iconType or nil
      local role = icon_type and ICON_ROLES[icon_type] or nil
      if role then
        roles[role] = true
        badges[#badges + 1] = { kind = role, label = label }
      elseif badge.customThumbnail then
        roles.member = true
        badges[#badges + 1] = {
          kind = "member",
          label = label,
          months = months_from_label(label),
          icon_url = Common.thumbnail_url(badge.customThumbnail)
        }
      elseif label then
        badges[#badges + 1] = { kind = "custom", label = label }
      end
    end
  end
  return badges, roles
end

--- Short textual prefix for degraded badge display, e.g. "[MOD]".
function Badges.prefix(badges, roles)
  local tags = {}
  if roles and roles.owner then
    tags[#tags + 1] = "OWNER"
  end
  if roles and roles.moderator then
    tags[#tags + 1] = "MOD"
  end
  if roles and roles.verified then
    tags[#tags + 1] = "✓"
  end
  if roles and roles.member and not (roles and roles.owner) then
    local months = nil
    for _, badge in ipairs(badges or {}) do
      if badge.kind == "member" and badge.months then
        months = badge.months
        break
      end
    end
    tags[#tags + 1] = months and ("MEMBER·" .. months .. "m") or "MEMBER"
  end
  if #tags == 0 then
    return nil
  end
  return "[" .. table.concat(tags, "|") .. "]"
end

return Badges
