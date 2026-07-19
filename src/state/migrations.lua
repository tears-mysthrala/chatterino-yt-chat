local Migrations = {}

Migrations.SCHEMA_VERSION = 1

local function ensure_tables(state)
  state.settings = state.settings or {}
  state.channels = state.channels or {}
  state.schema_version = state.schema_version or 0
  return state
end

function Migrations.upgrade(state)
  local out = ensure_tables(state or {})
  if out.schema_version < 1 then
    out.settings.offline_poll_schedule = out.settings.offline_poll_schedule or { 30, 60, 120, 300 }
    out.settings.offline_poll_max = out.settings.offline_poll_max or 300
    out.settings.chat_poll_min_ms = out.settings.chat_poll_min_ms or 500
    out.settings.chat_poll_max_ms = out.settings.chat_poll_max_ms or 15000
    out.settings.chat_poll_fallback_ms = out.settings.chat_poll_fallback_ms or 1000
    out.settings.debug = out.settings.debug == true
    out.schema_version = 1
  end
  return out
end

return Migrations
