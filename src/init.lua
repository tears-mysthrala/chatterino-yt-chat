local Persistence = require("src.state.persistence")
local Commands = require("src.commands")
local Logging = require("src.support.logging")

local Plugin = {}

local state = Persistence.read()
local state_hash = nil

local function persist(updated_state)
  local new_hash, ok = Persistence.write_if_changed(updated_state, state_hash)
  if ok then
    state_hash = new_hash
  end
  return new_hash, ok
end

function Plugin.bootstrap()
  Logging.set_debug(state.settings and state.settings.debug or false)
  Commands.register(state, persist)
  c2.later(function()
    Commands.run_offline_poll_once(state)
  end, 30000)
end

return Plugin
