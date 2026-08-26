-- Load/performance scenarios from GOAL.md: 10 offline channels, 5 active
-- streams, one stream across several splits, high-activity chat, hours of
-- simulated time. Asserts bounded state and no duplicate network activity.
local T = require("tests.test_runner")
local json = require("libs/json")
local C2Mock = require("tests.harness.c2_mock")

local mock = C2Mock.install()
local Clock = require("src.support.clock")
Clock._set(function()
  return mock.now_ms
end)
local Backoff = require("src.support.backoff")
Backoff._random = function()
  return 0
end

local Persistence = require("src.state.persistence")
local DIR = os.getenv("TMPDIR") or "/tmp"
local test_dir = DIR .. "/cyc_load_spec"
os.execute("rm -rf " .. test_dir)
os.execute("mkdir -p " .. test_dir)
Persistence._set_dir(test_dir)

local ActiveStreams = require("src.state.active_streams")
ActiveStreams._reset()
require("src.youtube.polling")._reset()
local Polling = require("src.youtube.polling")

local function text_actions(prefix, count)
  local actions = {}
  for i = 1, count do
    actions[i] = {
      addChatItemAction = {
        item = {
          liveChatTextMessageRenderer = {
            id = prefix .. "-" .. i,
            authorName = { simpleText = "user" .. (i % 50) },
            timestampUsec = "1784468624206879",
            message = { runs = { { text = "message number " .. i } } }
          }
        }
      }
    }
  end
  return actions
end

local function payload(actions)
  return json.encode({
    continuationContents = {
      liveChatContinuation = {
        actions = actions,
        continuations = {
          { invalidationContinuationData = { continuation = "NEXT", timeoutMs = 1000 } }
        }
      }
    }
  })
end

local busy_actions = text_actions("m", 120)

mock.http_responder = function(_, url, _)
  if url:find("get_live_chat", 1, true) then
    return { status = 200, data = payload(busy_actions) }
  end
  return { status = 200, data = "<html>no live markers here</html>" }
end

-- 5 active streams; stream-1 is shown in 3 splits --------------------------
for i = 1, 5 do
  mock.add_channel("split" .. i)
end
local state = { settings = require("src.state.migrations").default_settings(), channels = {} }
local persist_count = 0
local persist = function()
  persist_count = persist_count + 1
end

for i = 1, 5 do
  local video = "video" .. i
  local splits = (i == 1) and { "split1", "split2", "split3" } or { "split" .. i }
  ActiveStreams.add_stream(video, "channel" .. i, splits)
  T.ok(Polling.start({
    videoId = video,
    apiKey = "K",
    clientVersion = "V",
    continuation = "C",
    channelName = "channel" .. i
  }), "polling starts for " .. video)
end

T.eq(Polling.active_count(), 5, "five active polls")
T.eq(mock.count_requests("get_live_chat"), 5, "one request per video")
T.eq(#mock.channels.split4.messages, 0, "initial history is not rendered")
-- split2 sees video1 (3 splits) + video2 (1 split): proves distribution to
-- multiple splits happens without any extra HTTP request.
T.eq(#mock.channels.split2.messages, 0, "initial history is not copied across splits")

busy_actions = text_actions("live", 120)
mock.advance(1000, 2000)
T.eq(#mock.channels.split4.messages, 120, "new live messages remain complete")
T.eq(#mock.channels.split2.messages, 240, "new live messages reach every split")

-- High activity: 120 s of 1 s polls per stream ------------------------------
local requests_before_high_activity = mock.count_requests("get_live_chat")
mock.advance(120000, 2000)
T.eq(mock.count_requests("get_live_chat"), requests_before_high_activity + 5 * 120, "single poll chain per video")
T.ok(ActiveStreams.dedupe_size("video1") <= 5000, "dedupe cache bounded")
T.ok(mock.pending_timers() <= 6, "no orphan timers (one per stream + monitor)")
T.eq(persist_count, 0, "no persistence writes during chat traffic")

-- Split close: removing all splits stops that stream's polling --------------
ActiveStreams.remove_split("split" == "x" and "video1" or "video1", "split1")
ActiveStreams.remove_split("video1", "split2")
ActiveStreams.remove_split("video1", "split3")
T.eq(ActiveStreams.active_video_count(), 4, "stream state cleaned when splits close")
local before = mock.count_requests("get_live_chat")
mock.advance(5000)
-- 4 remaining streams poll once per second for 5 s; the closed stream
-- contributes zero requests.
T.eq(mock.count_requests("get_live_chat"), before + 4 * 5, "closed stream stops polling")

-- 10 offline channels: single check per channel per backoff ------------------
for i = 1, 10 do
  state.channels["UCOFF" .. i] = {
    channel_id = "UCOFF" .. i,
    splits = { "split" .. ((i % 5) + 1) }
  }
end
Polling.start_offline_monitor(state, persist)
mock.advance(1000) -- first pass: all channels checked once
local offline_requests_1 = mock.count_requests("youtube.com/channel")
T.eq(offline_requests_1, 10, "one offline check per channel")

-- Backoff: second check at +30 s, third at +60 s ---------------------------
mock.advance(29000)
T.eq(mock.count_requests("youtube.com/channel"), 10, "no early recheck")
mock.advance(2000)
T.eq(mock.count_requests("youtube.com/channel"), 20, "second check after 30 s")
mock.advance(58000)
T.eq(mock.count_requests("youtube.com/channel"), 20, "no check before 60 s step")
mock.advance(3000)
T.eq(mock.count_requests("youtube.com/channel"), 30, "third check after 60 s")

-- Simulated hours: backoff capped, state bounded. Stop the busy streams
-- first so the long phase only exercises the offline monitor.
local chat_requests_before_stop = mock.count_requests("get_live_chat")
for i = 2, 5 do
  Polling.stop("video" .. i)
end
T.eq(Polling.active_count(), 0, "all streams stopped before long run")
mock.advance(3 * 3600 * 1000, 20000)
local per_channel = 0
for _, req in ipairs(mock.requests) do
  if req.url == "https://www.youtube.com/channel/UCOFF1/live" then
    per_channel = per_channel + 1
  end
end
-- 30+60+120 then 300 s steps over 3 h: ~40 checks, never a busy loop.
T.ok(per_channel >= 35 and per_channel <= 45, "offline backoff schedule holds over hours")
T.ok(mock.pending_timers() <= 2, "timers bounded after hours")
T.eq(ActiveStreams.dedupe_size("video1"), 0, "dedupe cleaned with stream")
T.eq(mock.count_requests("get_live_chat"), chat_requests_before_stop, "no chat polling after streams stop")

os.execute("rm -rf " .. test_dir)
