-- Monotonic millisecond clock.
--
-- Chatterino's plugin sandbox does not expose the `os` library at all, so
-- there is no os.time/os.clock. Inside Chatterino the clock is driven by a
-- heartbeat chained on c2.later (1 s resolution, monotonic, drift-tolerant
-- for backoff/rate-limit/TTL purposes). Outside Chatterino (tests, plain
-- Lua) it uses os.time.
local Clock = {}

local has_os_time = type(os) == "table" and type(os.time) == "function"

local tick_ms = 0
local heartbeat_started = false

local default_now = function()
  if has_os_time then
    return os.time() * 1000
  end
  return tick_ms
end

-- Replaceable for tests.
Clock.now_ms = default_now

--- Starts the heartbeat (Chatterino only). Safe to call once; later_fn is
--- c2.later-compatible. No-op when os.time exists or already started.
function Clock.start_heartbeat(later_fn)
  if heartbeat_started or has_os_time or type(later_fn) ~= "function" then
    return
  end
  heartbeat_started = true
  local function beat()
    tick_ms = tick_ms + 1000
    later_fn(beat, 1000)
  end
  later_fn(beat, 1000)
end

--- Test helper: install a fake clock. Call Clock._reset() to restore.
function Clock._set(fn)
  Clock.now_ms = fn
end

function Clock._reset()
  Clock.now_ms = default_now
end

return Clock
