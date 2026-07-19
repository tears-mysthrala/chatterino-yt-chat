local Channels = {}

local function stable_key(channel_id, handle)
  if type(channel_id) == "string" and channel_id ~= "" then
    return channel_id
  end
  if type(handle) == "string" and handle ~= "" then
    return "handle:" .. handle
  end
  return nil
end

function Channels.add_binding(state, channel_id, handle, split_name)
  state.channels = state.channels or {}
  local key = stable_key(channel_id, handle)
  if not key then
    return nil, "missing_channel_identifier"
  end
  local entry = state.channels[key] or {
    channel_id = channel_id,
    handle = handle,
    splits = {}
  }
  local exists = false
  for _, s in ipairs(entry.splits) do
    if s == split_name then
      exists = true
      break
    end
  end
  if not exists then
    table.insert(entry.splits, split_name)
  end
  state.channels[key] = entry
  return key, nil
end

function Channels.get_splits(state, key)
  local entry = state.channels and state.channels[key]
  if not entry then
    return {}
  end
  return entry.splits or {}
end

return Channels
