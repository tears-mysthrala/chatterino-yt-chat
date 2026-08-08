local Channels = {}

local MAX_SPLITS = 64

local function key_for(channel_id, handle)
  if type(channel_id) == "string" and channel_id ~= "" then
    return channel_id
  end
  if type(handle) == "string" and handle ~= "" then
    return "handle:" .. handle
  end
  return nil
end

--- Finds the key of an existing entry matching channel_id or handle,
--- so the same logical channel added via different URLs is not duplicated.
function Channels.resolve_key(state, channel_id, handle)
  local channels = state.channels or {}
  if type(channel_id) == "string" and channel_id ~= "" and channels[channel_id] then
    return channel_id
  end
  local handle_key = handle and ("handle:" .. handle) or nil
  if handle_key and channels[handle_key] then
    return handle_key
  end
  for key, entry in pairs(channels) do
    if type(entry) == "table" then
      if channel_id and entry.channel_id == channel_id then
        return key
      end
      if handle and entry.handle == handle then
        return key
      end
    end
  end
  return nil
end

--- Registers (or merges) a channel binding and attaches a split.
--- Returns the stable key or nil + error.
function Channels.add_binding(state, channel_id, handle, split_name)
  state.channels = state.channels or {}
  local existing_key = Channels.resolve_key(state, channel_id, handle)
  local final_key = key_for(channel_id, handle) or existing_key
  if not final_key then
    return nil, "missing_channel_identifier"
  end

  local entry
  if existing_key then
    entry = state.channels[existing_key]
    if existing_key ~= final_key then
      -- Upgrade a handle-keyed entry to its stable channel_id key.
      state.channels[existing_key] = nil
      state.channels[final_key] = entry
    end
  else
    entry = { splits = {} }
    state.channels[final_key] = entry
  end

  if type(channel_id) == "string" and channel_id ~= "" then
    entry.channel_id = channel_id
  end
  if type(handle) == "string" and handle ~= "" then
    entry.handle = handle
  end
  entry.splits = entry.splits or {}

  if type(split_name) == "string" and split_name ~= "" then
    local exists = false
    for _, s in ipairs(entry.splits) do
      if s == split_name then
        exists = true
        break
      end
    end
    if not exists and #entry.splits < MAX_SPLITS then
      table.insert(entry.splits, split_name)
    end
  end
  return final_key, nil
end

function Channels.set_display_name(state, key, display_name)
  local entry = state.channels and state.channels[key]
  if entry and type(display_name) == "string" and display_name ~= "" then
    entry.display_name = display_name
  end
end

function Channels.remove_split(state, key, split_name)
  local entry = state.channels and state.channels[key]
  if not entry or type(entry.splits) ~= "table" then
    return false
  end
  for i, s in ipairs(entry.splits) do
    if s == split_name then
      table.remove(entry.splits, i)
      return true
    end
  end
  return false
end

function Channels.get_splits(state, key)
  local entry = state.channels and state.channels[key]
  if not entry then
    return {}
  end
  return entry.splits or {}
end

function Channels.remove(state, key)
  if not (state.channels and state.channels[key]) then
    return false
  end
  state.channels[key] = nil
  return true
end

function Channels.set_paused(state, key, paused)
  local entry = state.channels and state.channels[key]
  if not entry then
    return false
  end
  entry.paused = paused == true
  return true
end

function Channels.find(state, term)
  if type(term) ~= "string" then
    return nil
  end
  if state.channels and state.channels[term] then
    return term
  end
  local needle = term:lower():gsub("^@", "")
  for key, entry in pairs(state.channels or {}) do
    if tostring(entry.handle or ""):lower():gsub("^@", "") == needle or
        tostring(entry.display_name or ""):lower() == needle or
        tostring(entry.channel_id or ""):lower() == needle then
      return key
    end
  end
  return nil
end

--- Iterates channels that still have at least one split attached.
function Channels.iter_active(state)
  local keys = {}
  for key, entry in pairs(state.channels or {}) do
    if type(entry) == "table" and type(entry.splits) == "table" and #entry.splits > 0 then
      keys[#keys + 1] = key
    end
  end
  table.sort(keys)
  return keys
end

return Channels
