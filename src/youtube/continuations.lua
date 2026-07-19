local Validation = require("src.support.validation")

local Continuations = {}

local function first(tbl)
  if type(tbl) ~= "table" then
    return nil
  end
  return tbl[1]
end

local function from_node(node)
  if type(node) ~= "table" then
    return nil
  end
  local invalidation = node.invalidationContinuationData
  if invalidation then
    return {
      token = invalidation.continuation,
      timeout_ms = invalidation.timeoutMs,
      type = "invalidationContinuationData"
    }
  end
  local timed = node.timedContinuationData
  if timed then
    return {
      token = timed.continuation,
      timeout_ms = timed.timeoutMs,
      type = "timedContinuationData"
    }
  end
  local replay = node.liveChatReplayContinuationData
  if replay then
    return {
      token = replay.continuation,
      timeout_ms = replay.timeoutMs,
      type = "liveChatReplayContinuationData"
    }
  end
  local inherited = node.reloadContinuationData
  if inherited then
    return {
      token = inherited.continuation,
      timeout_ms = inherited.timeoutMs,
      type = "reloadContinuationData"
    }
  end
  return nil
end

function Continuations.pick(payload)
  local c = payload and payload.continuationContents
  local lc = c and c.liveChatContinuation
  local candidates = lc and lc.continuations or nil
  local picked = from_node(first(candidates)) or from_node(payload and payload.invalidationContinuationData) or
      from_node(payload and payload.timedContinuationData)
  if not picked or type(picked.token) ~= "string" or picked.token == "" then
    return nil, "missing_continuation"
  end
  local timeout = Validation.clamp_number(picked.timeout_ms, 500, 15000, 1000)
  picked.timeout_ms = timeout
  return picked, nil
end

return Continuations
