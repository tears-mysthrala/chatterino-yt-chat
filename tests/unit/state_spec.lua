local T = require("tests.test_runner")
local Channels = require("src.state.channels")
local ActiveStreams = require("src.state.active_streams")

-- channels: add and dedupe by channel_id
do
  local state = { channels = {} }
  local key1 = Channels.add_binding(state, "UC123", "creator", "split1")
  T.eq(key1, "UC123", "channel_id preferred as key")
  local key2 = Channels.add_binding(state, "UC123", "creator", "split2")
  T.eq(key2, "UC123", "same channel resolves to same key")
  T.eq(#state.channels.UC123.splits, 2, "both splits attached")
  -- same split twice: no duplicate
  Channels.add_binding(state, "UC123", "creator", "split1")
  T.eq(#state.channels.UC123.splits, 2, "duplicate split ignored")
end

-- channels: handle-only entry upgraded when channel_id arrives
do
  local state = { channels = {} }
  local k1 = Channels.add_binding(state, nil, "creator", "s1")
  T.eq(k1, "handle:creator", "handle key when no id")
  local k2 = Channels.add_binding(state, "UC999", "creator", "s2")
  T.eq(k2, "UC999", "upgraded to channel_id key")
  T.eq(state.channels["handle:creator"], nil, "old handle key removed")
  T.eq(#state.channels.UC999.splits, 2, "splits merged across keys")
end

-- channels: remove_split and iter_active
do
  local state = { channels = {} }
  Channels.add_binding(state, "UC1", nil, "a")
  Channels.add_binding(state, "UC2", nil, "b")
  T.eq(#Channels.iter_active(state), 2, "two active channels")
  T.ok(Channels.remove_split(state, "UC1", "a"), "split removed")
  T.eq(#Channels.iter_active(state), 1, "channel without splits inactive")
  T.ok(not Channels.remove_split(state, "UC1", "zzz"), "missing split returns false")
  T.ok(Channels.set_paused(state, "UC2", true), "channel can be paused")
  T.ok(state.channels.UC2.paused, "paused state stored")
  T.eq(Channels.find(state, "UC2"), "UC2", "channel found by key")
  T.ok(Channels.remove(state, "UC2"), "channel removed")
  T.eq(state.channels.UC2, nil, "removed channel absent")
end

-- active_streams: splits lifecycle
do
  ActiveStreams._reset()
  ActiveStreams.add_stream("vid1", "Canal", { "s1", "s2" })
  T.eq(ActiveStreams.active_video_count(), 1, "one active video")
  T.eq(#ActiveStreams.get_splits("vid1"), 2, "two splits")
  ActiveStreams.add_stream("vid1", "Canal", { "s2", "s3" })
  T.eq(#ActiveStreams.get_splits("vid1"), 3, "split merge without duplicates")
  ActiveStreams.remove_split("vid1", "s1")
  ActiveStreams.remove_split("vid1", "s2")
  T.eq(ActiveStreams.active_video_count(), 1, "video alive while splits remain")
  ActiveStreams.remove_split("vid1", "s3")
  T.eq(ActiveStreams.active_video_count(), 0, "last split removal cleans video")
  ActiveStreams.remove_split("ghost", "x") -- must not error
  T.ok(true, "remove_split on unknown video is safe")
end

-- active_streams: dedupe with TTL and size cap
do
  ActiveStreams._reset()
  local now = 1000000
  ActiveStreams._now = function() return now end
  T.ok(not ActiveStreams.seen_message("v", "m1"), "first sight is new")
  T.ok(ActiveStreams.seen_message("v", "m1"), "second sight is duplicate")
  T.ok(not ActiveStreams.seen_message("v", "m2"), "different id is new")
  T.eq(ActiveStreams.dedupe_size("v"), 2, "two ids cached")
  now = now + 31 * 60 * 1000 -- past 30 min TTL
  T.ok(not ActiveStreams.seen_message("v", "m1"), "expired id is new again")
  -- size cap
  for i = 1, 6000 do
    ActiveStreams.seen_message("big", "id-" .. i)
  end
  T.ok(ActiveStreams.dedupe_size("big") <= 5000, "dedupe cache capped at 5000")
  ActiveStreams._now = function() return os.time() * 1000 end
end

-- active_streams: in-flight guard and cleanup
do
  ActiveStreams._reset()
  ActiveStreams.add_stream("vx", "c", { "s" })
  ActiveStreams.set_in_flight("vx", true)
  T.ok(ActiveStreams.is_in_flight("vx"), "in flight set")
  ActiveStreams.seen_message("vx", "m")
  ActiveStreams.cleanup_video("vx")
  T.ok(not ActiveStreams.is_in_flight("vx"), "cleanup clears in-flight")
  T.eq(ActiveStreams.dedupe_size("vx"), 0, "cleanup clears dedupe")
  T.eq(ActiveStreams.active_video_count(), 0, "cleanup clears video")
end
