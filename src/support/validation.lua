local Validation = {}

Validation.ALLOWED_HOSTS = {
  ["www.youtube.com"] = true,
  ["youtube.com"] = true,
  ["m.youtube.com"] = true,
  ["youtu.be"] = true,
  ["www.youtu.be"] = true
}

-- Hosts that YouTube chat payloads reference for emotes/stickers/avatars.
-- Only valid as image sources, never as API endpoints.
Validation.ALLOWED_IMAGE_HOSTS = {
  ["i.ytimg.com"] = true,
  ["yt3.ggpht.com"] = true,
  ["yt4.ggpht.com"] = true,
  ["yt3.googleusercontent.com"] = true,
  ["lh3.googleusercontent.com"] = true
}

Validation.MAX_URL_LEN = 2048
Validation.MAX_TEXT_LEN = 4000
Validation.MAX_AUTHOR_LEN = 200
Validation.MAX_ID_LEN = 128
Validation.MAX_RUNS = 200

function Validation.is_https_url(url)
  return type(url) == "string" and url:match("^https://") ~= nil
end

function Validation.extract_host(url)
  if type(url) ~= "string" then
    return nil
  end
  return url:match("^https://([^/%?#]+)")
end

function Validation.is_allowed_host(host)
  return Validation.ALLOWED_HOSTS[host or ""] == true
end

function Validation.is_allowed_image_host(host)
  return Validation.ALLOWED_IMAGE_HOSTS[host or ""] == true
end

function Validation.is_safe_https_youtube(url)
  if not Validation.is_https_url(url) then
    return false
  end
  if #url > Validation.MAX_URL_LEN then
    return false
  end
  local host = Validation.extract_host(url)
  if not Validation.is_allowed_host(host) then
    return false
  end
  return true
end

function Validation.is_safe_image_url(url)
  if not Validation.is_https_url(url) then
    return false
  end
  if #url > Validation.MAX_URL_LEN then
    return false
  end
  return Validation.is_allowed_image_host(Validation.extract_host(url))
end

function Validation.max_len(value, limit)
  if type(value) ~= "string" then
    return false
  end
  return #value <= (tonumber(limit) or 0)
end

function Validation.clamp_number(value, min, max, fallback)
  local n = tonumber(value)
  if n == nil then
    return fallback
  end
  if n < min then
    return min
  end
  if n > max then
    return max
  end
  return n
end

--- Returns a printable, length-capped string. Non-strings become "".
--- Strips ASCII control characters except \n and \t.
function Validation.sanitize_text(value, max)
  if type(value) ~= "string" then
    return ""
  end
  local limit = tonumber(max) or Validation.MAX_TEXT_LEN
  local cleaned = value:gsub("[%c]", function(ch)
    if ch == "\n" or ch == "\t" then
      return ch
    end
    return ""
  end)
  if #cleaned > limit then
    cleaned = cleaned:sub(1, limit)
  end
  return cleaned
end

--- Keeps only characters valid in YouTube ids/tokens, capped in length.
function Validation.sanitize_id(value, max)
  if type(value) ~= "string" then
    return nil
  end
  local limit = tonumber(max) or Validation.MAX_ID_LEN
  local cleaned = value:gsub("[^%w_%-%.=]", "")
  if cleaned == "" then
    return nil
  end
  return cleaned:sub(1, limit)
end

function Validation.is_valid_color(value)
  local n = tonumber(value)
  return n ~= nil and n >= 0 and n <= 0xFFFFFFFF
end

--- Tolerant Retry-After parsing: accepts numbers, numeric strings, nil.
--- Chatterino's HTTPResponse exposes no headers, so this is for future use.
function Validation.parse_retry_after(value)
  local n = tonumber(value)
  if n == nil or n < 0 then
    return nil
  end
  return n
end

return Validation
