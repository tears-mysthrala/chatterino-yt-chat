local T = require("tests.test_runner")
local Persistence = require("src.state.persistence")

os.remove("YT_CHAT.json")
os.remove("YT_CHAT.json.bak")
os.remove("YT_CHAT.json.tmp")

local state = Persistence.read()
T.ok(type(state) == "table", "state read returns table")
T.eq(state.schema_version, 1, "schema version upgraded")

state.channels.demo = { channel_id = "UC1", splits = { "demo" } }
local hash, ok = Persistence.write_if_changed(state, nil)
T.ok(ok, "state write successful")
T.ok(type(hash) == "string", "state hash generated")

local state2 = Persistence.read()
T.ok(state2.channels.demo ~= nil, "state persisted")
