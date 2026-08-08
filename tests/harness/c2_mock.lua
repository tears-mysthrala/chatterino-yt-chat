-- Mock of the Chatterino c2 API for integration tests. Synchronous by
-- default: HTTP requests resolve immediately through a responder function
-- the test controls; timers are advanced manually.
local C2Mock = {}

function C2Mock.new()
  local mock = {
    channels = {},
    commands = {},
    callbacks = {},
    timers = {},
    requests = {},
    pending_http = {},
    defer_http = false,
    logs = {},
    now_ms = 0,
    -- test-controlled: fn(method, url, payload) -> {status=, data=, error=}
    http_responder = nil
  }

  local function new_channel(name)
    local ch = {
      name = name,
      messages = {},
      system_messages = {}
    }
    function ch:get_name()
      return name
    end
    function ch:is_valid()
      return true
    end
    function ch:add_message(msg)
      self.messages[#self.messages + 1] = msg
    end
    function ch:add_system_message(text)
      self.system_messages[#self.system_messages + 1] = text
    end
    function ch:find_message_by_id(id)
      for _, msg in ipairs(self.messages) do
        if msg.id == id then
          return msg
        end
      end
      return nil
    end
    function ch:replace_message(original, replacement)
      for i, msg in ipairs(self.messages) do
        if msg == original then
          self.messages[i] = replacement
          return true
        end
      end
      return false
    end
    function ch:count_messages()
      return #self.messages
    end
    return ch
  end

  mock.new_channel = new_channel

  local c2 = {}

  c2.HTTPMethod = { Get = "GET", Post = "POST" }
  c2.LogLevel = { Debug = "D", Info = "I", Warning = "W", Critical = "C" }
  c2.FontStyle = { ChatMediumBold = "bold", Tiny = "tiny", ChatMediumItalic = "italic" }
  c2.EventType = { CompletionRequested = "completion" }

  function c2.log(level, ...)
    local parts = {}
    for _, v in ipairs({ ... }) do
      parts[#parts + 1] = tostring(v)
    end
    mock.logs[#mock.logs + 1] = { level = level, text = table.concat(parts, " ") }
  end

  function c2.register_command(name, handler)
    mock.commands[name] = handler
    return true
  end

  function c2.register_callback(event_type, handler)
    mock.callbacks[event_type] = handler
    return true
  end

  function c2.later(callback, ms)
    mock.timers[#mock.timers + 1] = { cb = callback, due = mock.now_ms + (ms or 0) }
  end

  c2.Channel = {}
  function c2.Channel.by_name(name)
    return mock.channels[name]
  end

  c2.Message = {}
  function c2.Message.new(init)
    return init
  end

  c2.HTTPRequest = {}
  function c2.HTTPRequest.create(method, url)
    local req = {
      method = method,
      url = url,
      headers = {},
      payload = nil
    }
    function req:set_header(name, value)
      self.headers[name] = value
    end
    function req:set_payload(data)
      self.payload = data
    end
    function req:set_timeout(_)
    end
    function req:on_success(cb)
      self._success = cb
    end
    function req:on_error(cb)
      self._error = cb
    end
    function req:finally(cb)
      self._finally = cb
    end
    function req:execute()
      mock.requests[#mock.requests + 1] = { method = method, url = url, payload = self.payload }
      local function resolve()
        local result = mock.http_responder and mock.http_responder(method, url, self.payload) or
            { status = 0, error = "no responder" }
        local response = { _result = result }
        response.data = function() return result.data or "" end
        response.status = function() return result.status end
        response.error = function() return result.error or "" end
        if result.error then
          if self._error then self._error(response) end
        elseif self._success then
          self._success(response)
        end
        if self._finally then self._finally() end
      end
      if mock.defer_http then
        mock.pending_http[#mock.pending_http + 1] = resolve
      else
        resolve()
      end
    end
    return req
  end

  -- Test helpers -----------------------------------------------------------

  function mock.add_channel(name)
    mock.channels[name] = new_channel(name)
    return mock.channels[name]
  end

  function mock.remove_channel(name)
    mock.channels[name] = nil
  end

  function mock.run_command(name, split, ...)
    local handler = mock.commands[name]
    assert(handler, "command not registered: " .. name)
    local channel = mock.channels[split]
    assert(channel, "split does not exist: " .. split)
    handler({ words = { name, ... }, channel = channel })
  end

  --- Advances the mock clock and fires due timers (newly scheduled timers
  --- included). Guards against runaway scheduling.
  function mock.advance(ms, max_iterations)
    local target = mock.now_ms + ms
    local iterations = 0
    while true do
      local next_timer, next_index = nil, nil
      for i, timer in ipairs(mock.timers) do
        if timer.due <= target and (not next_timer or timer.due < next_timer.due) then
          next_timer, next_index = timer, i
        end
      end
      if not next_timer then
        break
      end
      table.remove(mock.timers, next_index)
      mock.now_ms = math.max(mock.now_ms, next_timer.due)
      next_timer.cb()
      iterations = iterations + 1
      assert(iterations <= (max_iterations or 1000), "timer runaway")
    end
    mock.now_ms = target
  end

  function mock.pending_timers()
    return #mock.timers
  end

  function mock.flush_http()
    local pending = mock.pending_http
    mock.pending_http = {}
    for _, resolve in ipairs(pending) do resolve() end
  end

  function mock.count_requests(url_substring)
    local n = 0
    for _, req in ipairs(mock.requests) do
      if not url_substring or req.url:find(url_substring, 1, true) then
        n = n + 1
      end
    end
    return n
  end

  mock.c2 = c2
  return mock
end

--- Installs the mock as the global c2; returns the mock.
function C2Mock.install()
  local mock = C2Mock.new()
  _G.c2 = mock.c2
  return mock
end

return C2Mock
