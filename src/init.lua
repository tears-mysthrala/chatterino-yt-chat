local Persistence = require("src.state.persistence")
local Commands = require("src.commands")
local Polling = require("src.youtube.polling")
local Logging = require("src.support.logging")
local Clock = require("src.support.clock")
local I18n = require("src.i18n")

local Plugin = {}

local state = Persistence.read()
local flush, get_hash = Persistence.create_flusher(2000, function(cb, ms)
  local c2 = rawget(_G, "c2")
  if c2 and c2.later then
    c2.later(cb, ms)
  else
    cb()
  end
end)

local function persist(updated_state)
  flush(updated_state)
end

function Plugin.bootstrap()
  Logging.set_debug(state.settings and state.settings.debug or false)
  I18n.set(state.settings and state.settings.language or "es")
  Polling.set_sync_delay(state.settings and state.settings.chat_sync_delay_ms or 0)
  local c2 = rawget(_G, "c2")
  Clock.start_heartbeat(c2 and c2.later)
  Commands.register(state, persist)
  Polling.start_offline_monitor(state, persist)
  Logging.info("plugin_loaded", { channels = #(require("src.state.channels").iter_active(state)) })
end

-- Exposed for the diagnostic self-test (docs/validation) and tests.
function Plugin._state()
  return state
end

function Plugin._persist()
  return persist, get_hash
end

return Plugin
