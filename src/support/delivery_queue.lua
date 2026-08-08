local Clock = require("src.support.clock")
local Logging = require("src.support.logging")
local Health = require("src.support.health")

local DeliveryQueue = {}
local queues = {}
local sequence = 0
local generation = 0
local MAX_ITEMS_PER_KEY = 128

local function run_item(key, item)
  local ok, err = pcall(item.callback)
  if not ok then
    Health.increment("delivery_errors")
    Logging.rate_limited("error", "delivery-queue:" .. key, 60000, 2,
      "delivery_queue_callback_error", { queue = key, error = tostring(err) })
  end
end

local function schedule_next(key, later_fn)
  local queue = queues[key]
  if not queue or queue.scheduled or #queue.items == 0 then
    return
  end
  queue.scheduled = true
  local scheduled_generation = queue.generation
  local wait_ms = math.max(0, queue.items[1].due_ms - Clock.now_ms())
  later_fn(function()
    local current = queues[key]
    if not current or current.generation ~= scheduled_generation then
      return
    end
    current.scheduled = false
    local now = Clock.now_ms()
    while #current.items > 0 and current.items[1].due_ms <= now do
      local item = table.remove(current.items, 1)
      run_item(key, item)
    end
    if #current.items == 0 then
      queues[key] = nil
    else
      schedule_next(key, later_fn)
    end
  end, wait_ms)
end

function DeliveryQueue.enqueue(key, delay_ms, callback, later_fn)
  if type(key) ~= "string" or type(callback) ~= "function" or type(later_fn) ~= "function" then
    return false
  end
  local queue = queues[key]
  if not queue then
    generation = generation + 1
    queue = { items = {}, scheduled = false, generation = generation }
    queues[key] = queue
  end
  sequence = sequence + 1
  local due_ms = Clock.now_ms() + math.max(0, math.floor(tonumber(delay_ms) or 0))
  if #queue.items > 0 then
    due_ms = math.max(due_ms, queue.items[#queue.items].due_ms)
  end
  queue.items[#queue.items + 1] = {
    due_ms = due_ms,
    sequence = sequence,
    callback = callback
  }
  if #queue.items > MAX_ITEMS_PER_KEY then
    Health.increment("queue_backpressure")
    run_item(key, table.remove(queue.items, 1))
  end
  table.sort(queue.items, function(a, b)
    return a.due_ms < b.due_ms or (a.due_ms == b.due_ms and a.sequence < b.sequence)
  end)
  schedule_next(key, later_fn)
  Health.max_gauge("max_queue_depth", #queue.items)
  return true
end

function DeliveryQueue.pending(key)
  local queue = queues[key]
  return queue and #queue.items or 0
end

function DeliveryQueue.cancel(key)
  queues[key] = nil
end

function DeliveryQueue._reset()
  queues = {}
  sequence = 0
  generation = generation + 1
end

return DeliveryQueue
