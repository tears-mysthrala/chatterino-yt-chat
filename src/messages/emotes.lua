local Common = require("src.messages.common")
local Validation = require("src.support.validation")

local Emotes = {}

local function unwrap_youtube_link(url)
  if type(url) ~= "string" then
    return nil
  end
  -- /redirect?...&q=https%3A%2F%2F... style outbound links
  local path, query = url:match("^(/redirect)%?(.*)$")
  if not path then
    path, query = url:match("^https://www%.youtube%.com(/redirect)%?(.*)$")
  end
  if path and query then
    local q = query:match("[?&]?q=([^&]+)")
    if q then
      local decoded = q:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
      end)
      return decoded
    end
    return nil
  end
  if url:match("^//") then
    return "https:" .. url
  end
  if url:match("^/") then
    return "https://www.youtube.com" .. url
  end
  return url
end

local function link_url(run)
  local endpoint = run.navigationEndpoint
  if type(endpoint) ~= "table" then
    return nil
  end
  local meta = endpoint.commandMetadata
  if type(meta) ~= "table" then
    return nil
  end
  local web = meta.webCommandMetadata
  if type(web) ~= "table" then
    return nil
  end
  local resolved = unwrap_youtube_link(web.url)
  if resolved and Validation.is_https_url(resolved) and #resolved <= Validation.MAX_URL_LEN then
    return resolved
  end
  return nil
end

local function emoji_run(emoji, out, flat)
  if type(emoji) ~= "table" then
    return
  end
  local emoji_id = type(emoji.emojiId) == "string" and emoji.emojiId or nil
  local shortcut = nil
  if type(emoji.shortcuts) == "table" and type(emoji.shortcuts[1]) == "string" then
    shortcut = emoji.shortcuts[1]
  end
  if emoji.isCustomEmoji == true then
    local name = shortcut or emoji_id or ":emote:"
    out[#out + 1] = {
      type = "emote",
      name = Common.safe_text(name, 80) or ":emote:",
      url = Common.thumbnail_url(emoji.image),
      custom = true
    }
    flat[#flat + 1] = name
  else
    -- Standard YouTube emoji: emojiId is the Unicode character itself.
    local char = emoji_id or shortcut or "?"
    out[#out + 1] = { type = "emoji", emoji = Common.safe_text(char, 32) or "?" }
    flat[#flat + 1] = char
  end
end

--- Parses message.runs into IR runs + flattened text. Runs without a text
--- or emoji property are never dropped: they become a visible "[?]" marker
--- and are counted in the third return value.
function Emotes.parse_runs(container)
  local out = {}
  local flat = {}
  local unknown_runs = 0
  if type(container) ~= "table" then
    return out, "", 0
  end
  local simple = Common.simple_text(container)
  if simple and type(container.runs) ~= "table" then
    out[1] = { type = "text", text = Common.safe_text(simple) or "" }
    return out, simple, 0
  end
  if type(container.runs) ~= "table" then
    return out, "", 0
  end
  for _, run in ipairs(container.runs) do
    if #out >= Validation.MAX_RUNS then
      break
    end
    if type(run) == "table" then
      if type(run.text) == "string" then
        local url = link_url(run)
        if url then
          out[#out + 1] = { type = "link", text = Common.safe_text(run.text, 512) or url, url = url }
        else
          out[#out + 1] = { type = "text", text = Common.safe_text(run.text, Validation.MAX_TEXT_LEN) or "" }
        end
        flat[#flat + 1] = run.text
      elseif run.emoji ~= nil then
        emoji_run(run.emoji, out, flat)
      else
        unknown_runs = unknown_runs + 1
        out[#out + 1] = { type = "text", text = "[?]" }
        flat[#flat + 1] = "[?]"
      end
    end
  end
  return out, table.concat(flat), unknown_runs
end

return Emotes
