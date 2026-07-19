local Badges = {}

local function badge_label(badge)
  if type(badge) ~= "table" then
    return nil
  end
  local r = badge.liveChatAuthorBadgeRenderer
  if type(r) ~= "table" then
    return nil
  end
  return r.tooltip or (r.icon and r.icon.iconType) or "badge"
end

function Badges.collect(author_badges)
  if type(author_badges) ~= "table" then
    return {}
  end
  local out = {}
  for _, b in ipairs(author_badges) do
    local lbl = badge_label(b)
    if lbl then
      table.insert(out, lbl)
    end
  end
  return out
end

return Badges
