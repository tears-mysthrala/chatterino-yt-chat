local Validation = {}

Validation.ALLOWED_HOSTS = {
  ["www.youtube.com"] = true,
  ["youtube.com"] = true,
  ["m.youtube.com"] = true,
  ["youtu.be"] = true,
  ["www.youtu.be"] = true
}

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

function Validation.is_safe_https_youtube(url)
  if not Validation.is_https_url(url) then
    return false
  end
  local host = Validation.extract_host(url)
  if not Validation.is_allowed_host(host) then
    return false
  end
  return true
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

return Validation
