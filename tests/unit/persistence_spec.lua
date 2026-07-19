local T = require("tests.test_runner")
local Persistence = require("src.state.persistence")

local DIR = os.getenv("TMPDIR") or "/tmp"
local test_dir = DIR .. "/cyc_persistence_spec"
os.execute("rm -rf " .. test_dir)
os.execute("mkdir -p " .. test_dir)
Persistence._set_dir(test_dir)

local function state_file()
  return test_dir .. "/YT_CHAT.json"
end

local function read_raw(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local raw = f:read("a")
  f:close()
  return raw
end

-- Fresh read yields defaults
local state = Persistence.read()
T.ok(type(state) == "table", "state read returns table")
T.eq(state.schema_version, 2, "schema version is 2")
T.eq(Persistence.last_recovery, "default", "fresh read marked as default")
T.eq(state.settings.debug, false, "debug default false")
T.eq(state.settings.offline_poll_max, 300, "offline max default")

-- Write round-trip
state.channels.UC1 = { channel_id = "UC1", splits = { "demo" } }
local hash, ok = Persistence.write_if_changed(state, nil)
T.ok(ok, "state write successful")
T.ok(type(hash) == "string", "state hash generated")

local state2 = Persistence.read()
T.ok(state2.channels.UC1 ~= nil, "state persisted")
T.eq(state2.channels.UC1.splits[1], "demo", "split persisted")
T.eq(Persistence.last_recovery, nil, "clean read has no recovery marker")

-- No rewrite when unchanged
local hash2, ok2 = Persistence.write_if_changed(state2, hash)
T.ok(ok2, "unchanged write reports ok")
T.eq(hash2, hash, "unchanged write keeps hash")

-- Backup created on second real write
state2.channels.UC2 = { channel_id = "UC2", splits = { "otro" } }
local hash3, ok3 = Persistence.write_if_changed(state2, hash2)
T.ok(ok3, "second write ok")
T.ok(hash3 ~= hash2, "hash changes on change")
T.ok(read_raw(state_file() .. ".bak") ~= nil, ".bak created")

-- Corrupt main + valid .bak recovers from backup
local wf = io.open(state_file(), "w")
wf:write("{not json!!!")
wf:close()
local recovered = Persistence.read()
T.eq(Persistence.last_recovery, "bak", "recovery marker set to bak")
T.ok(recovered.channels.UC1 ~= nil, "channels recovered from bak")

-- Both corrupt -> defaults
local bf = io.open(state_file() .. ".bak", "w")
bf:write("garbage")
bf:close()
local fresh = Persistence.read()
T.eq(Persistence.last_recovery, "default", "both corrupt -> default")
T.eq(next(fresh.channels), nil, "default has no channels")

-- validate_schema drops junk and coerces
local dirty = Persistence.validate_schema({
  schema_version = 99,
  hacker = "drop me",
  settings = { debug = "yes", evil = true, offline_poll_max = "120" },
  channels = {
    UCX = { channel_id = "UCX", splits = { "a", 5, "b" }, payload = "drop" },
    [""] = { splits = {} }
  }
})
T.eq(dirty.hacker, nil, "unknown top-level key dropped")
T.eq(dirty.settings.debug, false, "non-boolean debug coerced")
T.eq(dirty.settings.evil, nil, "unknown setting dropped")
T.eq(dirty.settings.offline_poll_max, 120, "numeric string coerced")
T.eq(#dirty.channels.UCX.splits, 2, "non-string splits dropped")
T.eq(dirty.channels.UCX.payload, nil, "channel junk dropped")

-- Debounced flusher: bursts produce a single write
do
  local now = 1000000
  Persistence._now = function() return now end
  local scheduled = {}
  local later = function(cb, ms)
    scheduled[#scheduled + 1] = cb
  end
  local flush = Persistence.create_flusher(2000, later)
  local s = Persistence.read()
  s.channels.Q1 = { channel_id = "Q1", splits = { "x" } }
  flush(s) -- immediate (first write)
  s.channels.Q2 = { channel_id = "Q2", splits = { "y" } }
  flush(s) -- within interval -> scheduled
  flush(s) -- coalesced
  T.eq(#scheduled, 1, "burst schedules one delayed write")
  now = now + 2500
  scheduled[1]()
  local final = Persistence.read()
  T.ok(final.channels.Q1 ~= nil and final.channels.Q2 ~= nil, "debounced state written once with all changes")
  Persistence._now = function() return os.time() * 1000 end
end

-- Migration from legacy v0 shape
do
  local legacy = {
    settings = {},
    channels = {
      UCLEGACY123 = { splits = { "splitA", "splitB" } },
      ["handle:someone"] = { splits = { "splitC" } }
    }
  }
  local wf2 = io.open(state_file(), "w")
  wf2:write(require("libs/json").encode(legacy))
  wf2:close()
  local migrated = Persistence.read()
  T.eq(migrated.schema_version, 2, "legacy migrated to v2")
  T.ok(migrated.channels.UCLEGACY123 ~= nil, "channel id key kept")
  T.eq(migrated.channels.UCLEGACY123.channel_id, "UCLEGACY123", "channel_id inferred from key")
  T.eq(migrated.channels.UCLEGACY123.splits[2], "splitB", "splits preserved")
  T.ok(migrated.channels["handle:someone"] ~= nil, "handle key kept")
  T.eq(migrated.channels["handle:someone"].handle, "someone", "handle inferred from key")
end

os.execute("rm -rf " .. test_dir)
