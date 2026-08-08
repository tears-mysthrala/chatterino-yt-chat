local Builder = {}

-- Deterministic author colors (same palette idea as the original plugin).
local AUTHOR_COLORS = {
  "blue", "coral", "dodgerBlue", "springGreen", "yellowGreen", "green",
  "orangeRed", "red", "goldenRod", "hotPink", "cadetBlue", "seaGreen",
  "chocolate", "blueViolet", "firebrick"
}

local function author_color(name)
  local total = 0
  for i = 1, #name do
    total = total + string.byte(name, i)
  end
  return AUTHOR_COLORS[(total % #AUTHOR_COLORS) + 1]
end

local function text_element(text, opts)
  local element = { type = "text", text = text }
  if opts then
    for k, v in pairs(opts) do
      element[k] = v
    end
  end
  return element
end

local function add_prefix(elements, event, show_channel)
  elements[#elements + 1] = text_element("▶️", { color = "red", style = "ChatMediumBold" })
  elements[#elements + 1] = text_element("YT", { color = "system", style = "ChatMediumBold" })
  local ts = nil
  if type(event.timestamp_usec) == "number" then
    ts = math.floor(event.timestamp_usec / 1000)
  end
  elements[#elements + 1] = { type = "timestamp", time = ts }
  if show_channel and type(event.channel_name) == "string" and event.channel_name ~= "" then
    elements[#elements + 1] = text_element("(" .. event.channel_name .. ")", { color = "system", style = "Tiny" })
  end
end

local function add_runs(elements, event)
  local parts = {}
  if type(event.runs) == "table" then
    for _, run in ipairs(event.runs) do
      if run.type == "text" and run.text then
        parts[#parts + 1] = run.text
      elseif run.type == "link" then
        parts[#parts + 1] = run.text or run.url or ""
      elseif run.type == "emoji" and run.emoji then
        parts[#parts + 1] = run.emoji
      elseif run.type == "emote" then
        parts[#parts + 1] = run.name or ":emote:"
      end
    end
  end
  local body = table.concat(parts)
  if body == "" and type(event.text) == "string" then
    body = event.text
  end
  if body ~= "" then
    elements[#elements + 1] = text_element(body)
  end
  return body
end

local function badge_tag(event)
  local Badges = require("src.messages.badges")
  return Badges.prefix(event.badges, event.roles)
end

local function author_element(elements, event)
  if type(event.author_photo) == "string" and event.author_photo ~= "" then
    elements[#elements + 1] = { type = "remote-image", url = event.author_photo, size = 18, circular = true }
  end
  local author = event.author or "[?]"
  local tag = badge_tag(event)
  local label = tag and (tag .. " " .. author .. ":") or (author .. ":")
  elements[#elements + 1] = text_element(label, { color = author_color(author), style = "ChatMediumBold" })
end

local function chat_spec(event, elements, message_text, extra)
  local spec = {
    id = event.id and ("yt-chat-" .. event.id) or nil,
    message_text = "▶️ YT " .. (message_text or ""),
    elements = elements,
    system = false,
    display_name = event.author,
    login_name = event.author,
    highlight_color = event.highlight_color
  }
  if extra then
    for k, v in pairs(extra) do
      spec[k] = v
    end
  end
  return spec
end

local function system_spec(text)
  return {
    system = true,
    message_text = "▶️ YT " .. text,
    elements = {}
  }
end

local function amount_label(base, amount)
  if amount and amount ~= "" then
    return "[" .. base .. " · " .. amount .. "]"
  end
  return "[" .. base .. "]"
end

local function fmt_votes(option)
  local label = option.text or "?"
  if option.votes then
    label = label .. " (" .. option.votes .. ")"
  end
  if option.ratio then
    label = label .. string.format(" %.0f%%", option.ratio * 100)
  end
  return label
end

local handlers = {}

handlers.text_message = function(event, elements)
  author_element(elements, event)
  local body = add_runs(elements, event)
  return chat_spec(event, elements, (event.author or "") .. ": " .. body)
end

handlers.super_chat = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Super Chat", event.amount),
    { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  local body = add_runs(elements, event)
  return chat_spec(event, elements,
    "Super Chat " .. (event.amount or "") .. " " .. (event.author or "") .. ": " .. body)
end

handlers.super_sticker = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Super Sticker", event.amount),
    { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  local alt = event.sticker and event.sticker.alt or "sticker"
  if event.sticker and event.sticker.url then
    elements[#elements + 1] = { type = "remote-image", url = event.sticker.url, size = 32 }
  end
  elements[#elements + 1] = text_element("sticker “" .. alt .. "”")
  return chat_spec(event, elements,
    "Super Sticker " .. (event.amount or "") .. " " .. (event.author or "") .. ": sticker " .. alt)
end

handlers.donation = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Donation", event.amount),
    { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  local body = add_runs(elements, event)
  return chat_spec(event, elements, "Donation " .. (event.amount or "") .. " " .. (event.author or "") .. ": " .. body)
end

handlers.legacy_paid = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Member", event.amount),
    { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  if event.header_text then
    elements[#elements + 1] = text_element(event.header_text, { color = "system" })
  end
  local body = add_runs(elements, event)
  return chat_spec(event, elements, "Member " .. (event.author or "") .. " " .. (event.header_text or body))
end

handlers.membership = function(event, elements)
  local label
  if event.membership_kind == "milestone" then
    label = "[Member" .. (event.member_since and (" · " .. event.member_since) or "") .. "]"
  else
    label = "[New member" .. (event.level and (" · " .. event.level) or "") .. "]"
  end
  elements[#elements + 1] = text_element(label, { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  if event.membership_kind == "milestone" then
    local body = add_runs(elements, event)
    return chat_spec(event, elements, "Member milestone " .. (event.author or "") .. ": " .. body)
  end
  elements[#elements + 1] = text_element(event.header_text or "New member", { color = "system" })
  return chat_spec(event, elements, "New member " .. (event.author or ""))
end

handlers.membership_gift = function(event, elements)
  elements[#elements + 1] = text_element("[Gift ×" .. tostring(event.gift_count or 1) .. "]",
    { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  elements[#elements + 1] = text_element(event.header_text or
      ("gifted " .. tostring(event.gift_count or 1) .. " memberships"), { color = "system" })
  return chat_spec(event, elements,
    "Gift " .. tostring(event.gift_count or 1) .. " memberships by " .. (event.author or ""))
end

handlers.membership_gift_received = function(event, elements)
  elements[#elements + 1] = text_element("[Gift received]", { color = "system", style = "ChatMediumBold" })
  author_element(elements, event)
  local body = add_runs(elements, event)
  return chat_spec(event, elements, "Gift received " .. (event.author or "") .. " " .. body)
end

handlers.poll = function(event, elements)
  elements[#elements + 1] = text_element("[Poll]", { color = "system", style = "ChatMediumBold" })
  local poll = event.poll or {}
  if poll.question then
    elements[#elements + 1] = text_element(poll.question, { style = "ChatMediumBold" })
  end
  local options = {}
  for _, option in ipairs(poll.options or {}) do
    options[#options + 1] = fmt_votes(option)
  end
  if #options > 0 then
    elements[#elements + 1] = text_element(table.concat(options, " · "), { color = "system" })
  end
  local votes = poll.total_votes and (" · " .. poll.total_votes .. " votes") or ""
  return chat_spec(event, elements, "Poll: " .. (poll.question or "") .. " " .. table.concat(options, " / ") .. votes)
end

handlers.poll_update = handlers.poll

handlers.ticker_paid = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Ticker · Super Chat", event.amount),
    { color = "system" })
  author_element(elements, event)
  local body = event.text or ""
  if body ~= "" then
    elements[#elements + 1] = text_element(body)
  end
  return chat_spec(event, elements, "Ticker Super Chat " .. (event.amount or "") .. " " .. (event.author or "") .. " " .. body)
end

handlers.ticker_sticker = function(event, elements)
  elements[#elements + 1] = text_element(amount_label("Ticker · Super Sticker", event.amount),
    { color = "system" })
  author_element(elements, event)
  local alt = event.sticker and event.sticker.alt or "sticker"
  elements[#elements + 1] = text_element("sticker “" .. alt .. "”")
  return chat_spec(event, elements, "Ticker Super Sticker " .. (event.amount or "") .. " " .. (event.author or ""))
end

handlers.ticker_member = function(event, elements)
  elements[#elements + 1] = text_element("[Ticker · Member]", { color = "system" })
  author_element(elements, event)
  local detail = event.ticker and event.ticker.detail_text or nil
  if detail then
    elements[#elements + 1] = text_element(detail, { color = "system" })
  end
  return chat_spec(event, elements, "Ticker member " .. (event.author or "") .. " " .. (detail or ""))
end

-- System-category events become system messages.
local SYSTEM_TEXT = {
  deleted_message = function(event)
    return "🗑 Message deleted" .. (event.target_message_id and (" (id: " .. event.target_message_id .. ")") or "")
  end,
  author_deleted = function(event)
    return "🚫 " .. (event.system_text or "User messages removed") ..
        (event.target_author_channel_id and (" (channel: " .. event.target_author_channel_id .. ")") or "")
  end,
  replaced_message = function(event)
    return "✏ Message replaced" .. (event.target_message_id and (" (id: " .. event.target_message_id .. ")") or "")
  end,
  pinned = function(event)
    local pinned = event.pinned_message
    local who = pinned and pinned.author or "?"
    local what = pinned and (pinned.text or "") or ""
    return "📌 " .. (event.header_text or "Pinned") .. " — " .. who .. ": " .. what
  end,
  pin_removed = function()
    return "📌 Pinned message removed"
  end,
  poll_closed = function(event)
    if event.text and event.text ~= "" then
      return "📊 Poll results — " .. event.text
    end
    return "📊 Poll closed" .. (event.id and (" (id: " .. event.id .. ")") or "")
  end,
  mode_change = function(event)
    return "⚙ " .. (event.system_text or "Chat mode changed") ..
        (event.sub_text and (" — " .. event.sub_text) or "")
  end,
  system = function(event)
    return event.system_text or "YouTube system message"
  end,
  placeholder = function(event)
    return event.system_text or "…"
  end,
  unknown_event = function(event)
    return "⚠ " .. (event.system_text or "Unsupported event")
  end
}

--- Converts a normalized event into a Chatterino message spec.
--- Returns nil only when the event is not a table (defensive).
function Builder.to_chatterino_message(event, show_channel)
  if type(event) ~= "table" or type(event.kind) ~= "string" then
    return nil
  end
  local system_text_fn = SYSTEM_TEXT[event.kind]
  if system_text_fn then
    return system_spec(system_text_fn(event))
  end
  local handler = handlers[event.kind]
  if not handler then
    return system_spec("⚠ Unsupported event: " .. tostring(event.source_renderer or event.kind))
  end
  local elements = {}
  add_prefix(elements, event, show_channel)
  return handler(event, elements)
end

Builder._author_color = author_color

return Builder
