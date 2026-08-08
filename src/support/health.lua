local Clock = require("src.support.clock")

local Health = {}
local started_ms = Clock.now_ms()
local counters = {}
local gauges = {}

function Health.increment(name, amount)
  if type(name) ~= "string" then return end
  counters[name] = (counters[name] or 0) + math.max(0, tonumber(amount) or 1)
end

function Health.gauge(name, value)
  if type(name) == "string" and type(value) == "number" then gauges[name] = value end
end

function Health.max_gauge(name, value)
  if type(name) == "string" and type(value) == "number" then
    gauges[name] = math.max(gauges[name] or value, value)
  end
end

function Health.snapshot()
  local out = { uptime_ms = math.max(0, Clock.now_ms() - started_ms), counters = {}, gauges = {} }
  for key, value in pairs(counters) do out.counters[key] = value end
  for key, value in pairs(gauges) do out.gauges[key] = value end
  return out
end

function Health.reset()
  started_ms = Clock.now_ms()
  counters = {}
  gauges = {}
end

return Health
