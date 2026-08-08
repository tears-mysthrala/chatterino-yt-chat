-- Single module allowed to touch the Chatterino `c2` API for channels,
-- messages, HTTP and timers. Everything else stays pure and testable.
local Innertube = require("src.youtube.innertube")
local Validation = require("src.support.validation")

local Adapter = {}

local function c2()
  return rawget(_G, "c2")
end

local function materialize_elements(elements)
  local api = c2()
  local image_flag = api and api.MessageElementFlag and
      (api.MessageElementFlag.AlwaysShow or api.MessageElementFlag.EmoteImage) or nil
  local supports_images = api and api.Image and type(api.Image.from_url) == "function" and image_flag ~= nil
  local out = {}
  for _, element in ipairs(elements or {}) do
    if element.type ~= "remote-image" then
      out[#out + 1] = element
    elseif supports_images and Validation.is_safe_image_url(element.url) then
      local size = math.max(8, math.min(64, tonumber(element.size) or 18))
      local ok, image = pcall(api.Image.from_url, element.url, 1, { size, size })
      if ok and image then
        out[#out + 1] = {
          type = element.circular and "circular-image" or "image",
          image = image,
          padding = element.circular and 0 or nil,
          background = element.circular and "#00000000" or nil,
          flags = image_flag
        }
      end
    end
  end
  return out
end

function Adapter.available()
  return type(c2()) == "table"
end

function Adapter.later(callback, ms)
  local api = c2()
  if api and api.later then
    api.later(callback, math.max(0, math.floor(ms or 0)))
  end
end

function Adapter.channel(name)
  local api = c2()
  if api and api.Channel and api.Channel.by_name then
    local ok, ch = pcall(api.Channel.by_name, name)
    if ok then
      return ch
    end
  end
  return nil
end

--- Delivers a builder spec to every split. System specs use
--- add_system_message; chat specs build a c2.Message when possible and
--- degrade to a system message if message construction fails.
function Adapter.deliver(spec, splits)
  if type(spec) ~= "table" then
    return
  end
  for _, split in ipairs(splits or {}) do
    local ch = Adapter.channel(split)
    if ch then
      if spec.system then
        ch:add_system_message(spec.message_text or "[yt-chat]")
      else
        local api = c2()
        local msg = nil
        if api and api.Message and api.Message.new then
          local ok, created = pcall(api.Message.new, {
            id = spec.id,
            message_text = spec.message_text,
            elements = materialize_elements(spec.elements),
            login_name = spec.login_name,
            display_name = spec.display_name,
            username_color = spec.username_color,
            highlight_color = spec.highlight_color,
            flags = spec.flags
          })
          if ok then
            msg = created
          end
        end
        if msg then
          ch:add_message(msg)
        else
          ch:add_system_message(spec.message_text or "[yt-chat]")
        end
      end
    end
  end
end

function Adapter.system(split, text)
  local ch = Adapter.channel(split)
  if ch then
    ch:add_system_message("▶️ YT " .. tostring(text))
  end
end

--- Attempts an in-place replacement of a previously delivered message by
--- its YouTube id. The replacement keeps the original id so later
--- mutations still resolve. Returns true when at least one split applied
--- the replacement. Requires Chatterino >= 2.5.x
--- (find_message_by_id/replace_message).
function Adapter.replace_spec_by_youtube_id(youtube_id, spec, splits)
  if type(youtube_id) ~= "string" or youtube_id == "" or type(spec) ~= "table" then
    return false
  end
  local api = c2()
  if not (api and api.Message and api.Message.new) then
    return false
  end
  local mutated = false
  for _, split in ipairs(splits or {}) do
    local ch = Adapter.channel(split)
    if ch and ch.find_message_by_id and ch.replace_message then
      local ok, original = pcall(ch.find_message_by_id, ch, "yt-chat-" .. youtube_id)
      if ok and original then
        local init = {
          id = "yt-chat-" .. youtube_id,
          message_text = spec.message_text,
          elements = materialize_elements(spec.elements),
          login_name = spec.login_name,
          display_name = spec.display_name,
          highlight_color = spec.highlight_color
        }
        local ok2, replacement = pcall(api.Message.new, init)
        if ok2 and replacement then
          local ok3 = pcall(ch.replace_message, ch, original, replacement)
          mutated = mutated or ok3
        end
      end
    end
  end
  return mutated
end

--- Replaces a message with a plain marker (used for deletions).
function Adapter.replace_by_youtube_id(youtube_id, marker_text, splits)
  return Adapter.replace_spec_by_youtube_id(youtube_id, {
    message_text = marker_text,
    elements = {
      { type = "text", text = "▶️", color = "red", style = "ChatMediumBold" },
      { type = "text", text = "YT", color = "system", style = "ChatMediumBold" },
      { type = "text", text = marker_text, color = "system", style = "ChatMediumItalic" }
    }
  }, splits)
end

function Adapter.http_get(url)
  local api = c2()
  local request = api.HTTPRequest.create(api.HTTPMethod.Get, url)
  Innertube.default_headers(request)
  return request
end

function Adapter.http_post_json(url, payload)
  local api = c2()
  local request = api.HTTPRequest.create(api.HTTPMethod.Post, url)
  Innertube.default_headers(request)
  request:set_header("Content-Type", "application/json")
  request:set_payload(payload)
  return request
end

return Adapter
