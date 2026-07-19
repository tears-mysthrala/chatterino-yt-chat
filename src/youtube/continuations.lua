local Validation = require("src.support.validation")

local Continuations = {}

local MAX_TOKEN_LEN = 4096

-- Preference order: invalidation push-based continuations first, then
-- timed, then replay/reload variants.
local KINDS = {
  "invalidationContinuationData",
  "timedContinuationData",
  "liveChatReplayContinuationData",
  "reloadContinuationData",
  "seekContinuationData"
}

local function from_node(node)
  if type(node) ~= "table" then
    return nil
  end
  for _, kind in ipairs(KINDS) do
    local data = node[kind]
    if type(data) == "table" and type(data.continuation) == "string" and data.continuation ~= "" and
        #data.continuation <= MAX_TOKEN_LEN then
      return {
        token = data.continuation,
        timeout_ms = tonumber(data.timeoutMs),
        type = kind
      }
    end
  end
  return nil
end

--- Picks the next continuation token and interval from a get_live_chat
--- response. opts: { min_ms=500, max_ms=15000, fallback_ms=1000 }.
--- Returns picked table or nil + "missing_continuation".
--- A payload without continuationContents signals end of stream or
--- disabled chat; the caller distinguishes via actions/header presence.
function Continuations.pick(payload, opts)
  local cfg = opts or {}
  local min_ms = tonumber(cfg.min_ms) or 500
  local max_ms = tonumber(cfg.max_ms) or 15000
  local fallback_ms = tonumber(cfg.fallback_ms) or 1000

  local picked = nil
  local lc = payload and payload.continuationContents and payload.continuationContents.liveChatContinuation
  local candidates = lc and lc.continuations
  if type(candidates) == "table" then
    for _, node in ipairs(candidates) do
      picked = from_node(node)
      if picked then
        break
      end
    end
  end
  picked = picked or from_node(payload) -- top-level invalidation/timed fallback

  if not picked then
    return nil, "missing_continuation"
  end
  picked.timeout_ms = Validation.clamp_number(picked.timeout_ms, min_ms, max_ms, fallback_ms)
  return picked, nil
end

return Continuations
