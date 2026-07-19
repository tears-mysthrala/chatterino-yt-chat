-- End-to-end flow against a mocked Chatterino: command registration,
-- watch-page resolution, chat polling, multi-split distribution, dedupe,
-- in-place moderation, offline detection and stream end.
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
local test_dir = DIR .. "/cyc_harness_spec"
os.execute("rm -rf " .. test_dir)
os.execute("mkdir -p " .. test_dir)
Persistence._set_dir(test_dir)

local ActiveStreams = require("src.state.active_streams")
ActiveStreams._reset()
require("src.youtube.polling")._reset()

-- Synthetic YouTube responses ----------------------------------------------

local WATCH_HTML_LIVE = [[
<html><head><link rel="canonical" href="https://www.youtube.com/watch?v=FAKEVIDEO01"></head>
<body>
"INNERTUBE_API_KEY":"FAKE-KEY-123"
"INNERTUBE_CONTEXT_CLIENT_VERSION":"2.20260101.00.00"
"channelId":"UCFAKECHANNEL0000000001","isOwnerViewing":false
"author":"Test Channel","isLowLatencyLiveStream":true
"isLive":true
"continuation":"FAKE-CONT-1"
</body></html>
]]

local WATCH_HTML_OFFLINE = [[
<html><head><link rel="canonical" href="https://www.youtube.com/watch?v=FAKEVIDEO02"></head>
<body>
"INNERTUBE_API_KEY":"FAKE-KEY-123"
"INNERTUBE_CONTEXT_CLIENT_VERSION":"2.20260101.00.00"
"channelId":"UCFAKECHANNEL0000000002","isOwnerViewing":false
"author":"Offline Channel","isLowLatencyLiveStream":false
</body></html>
]]

local function chat_payload(actions, timeout_ms)
  return json.encode({
    continuationContents = {
      liveChatContinuation = {
        actions = actions,
        continuations = {
          { invalidationContinuationData = { continuation = "FAKE-CONT-NEXT", timeoutMs = timeout_ms or 2000 } }
        }
      }
    }
  })
end

local function text_action(id, author, text)
  return {
    addChatItemAction = {
      item = {
        liveChatTextMessageRenderer = {
          id = id,
          authorName = { simpleText = author },
          authorExternalChannelId = "UC" .. author,
          timestampUsec = "1784468624206879",
          message = { runs = { { text = text } } }
        }
      }
    }
  }
end

local live = true
local payload_queue = {}

mock.http_responder = function(method, url, _)
  if url:find("/youtubei/v1/live_chat/get_live_chat", 1, true) then
    local payload = payload_queue[1] or chat_payload({}, 2000)
    if #payload_queue > 0 then
      table.remove(payload_queue, 1)
    end
    return { status = 200, data = payload }
  end
  if url:find("youtube.com", 1, true) then
    if live then
      return { status = 200, data = WATCH_HTML_LIVE }
    end
    return { status = 200, data = WATCH_HTML_OFFLINE }
  end
  return { status = 404, data = "" }
end

-- Bootstrap -----------------------------------------------------------------

local Plugin = require("src.init")
mock.add_channel("splitA")
mock.add_channel("splitB")
Plugin.bootstrap()
T.ok(mock.commands["/yt-chat"] ~= nil, "command registered")

-- Add a live channel from splitA ---------------------------------------------

payload_queue[1] = chat_payload({
  text_action("m1", "alice", "hello chat"),
  text_action("m2", "bob", "second message")
}, 2000)

mock.run_command("/yt-chat", "splitA", "https://www.youtube.com/@test/live")
T.eq(mock.count_requests("get_live_chat"), 1, "polling started immediately")
T.eq(#mock.channels.splitA.messages, 2, "two messages delivered to splitA")
T.eq(mock.channels.splitA.messages[1].id, "yt-chat-m1", "message id prefixed")

-- Multi-split: same channel added from splitB — no duplicate polling --------

mock.run_command("/yt-chat", "splitB", "https://www.youtube.com/@test/live")
T.eq(mock.count_requests("get_live_chat"), 1, "no second polling for same video")

payload_queue[1] = chat_payload({ text_action("m3", "carol", "after split join") }, 2000)
mock.advance(2100)
T.eq(mock.count_requests("get_live_chat"), 2, "next poll scheduled by YouTube timeout")
T.eq(#mock.channels.splitB.messages, 1, "new message distributed to splitB")
T.eq(#mock.channels.splitA.messages, 3, "new message also in splitA")

-- Dedupe: re-delivered id is dropped -----------------------------------------

payload_queue[1] = chat_payload({
  text_action("m3", "carol", "after split join"),
  text_action("m4", "dan", "fresh")
}, 2000)
mock.advance(2100)
T.eq(#mock.channels.splitA.messages, 4, "duplicate id not rendered again")

-- Moderation: in-place deletion ----------------------------------------------

payload_queue[1] = chat_payload({
  { markChatItemAsDeletedAction = { targetItemId = "m1", deletedStateMessage = { runs = { { text = "Message deleted by moderator" } } } } }
}, 2000)
mock.advance(2100)
local replaced = mock.channels.splitA.messages[1]
T.ok(replaced.message_text:find("deleted", 1, true) ~= nil, "original message replaced by deletion marker")
T.eq(#mock.channels.splitA.messages, 4, "deletion does not append a new message")

-- Unknown action produces a visible system event -----------------------------

payload_queue[1] = chat_payload({ { brandNewAction2042 = { weird = true } } }, 2000)
mock.advance(2100)
local last_sys = mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]
T.ok(last_sys:find("brandNewAction2042", 1, true) ~= nil, "unknown action visible in chat")

-- Stream end: no continuationContents -> stop + cleanup -----------------------

payload_queue[1] = json.encode({ responseContext = {} })
mock.advance(2100)
T.eq(ActiveStreams.active_video_count(), 0, "stream cleaned after end")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("finalizado", 1, true) ~= nil,
  "stream end announced")
local polls_after_end = mock.count_requests("get_live_chat")
mock.advance(10000)
T.eq(mock.count_requests("get_live_chat"), polls_after_end, "no polling after stream end")

-- Reconnection: transient HTTP 500 -> bounded backoff retry -> recovery ----

live = true
local fail_next = 1
local base_responder = mock.http_responder
mock.http_responder = function(method, url, payload)
  if fail_next > 0 and url:find("get_live_chat", 1, true) then
    fail_next = fail_next - 1
    return { status = 500, data = "" }
  end
  return base_responder(method, url, payload)
end

payload_queue[1] = chat_payload({ text_action("m8", "zoe", "after reconnect") }, 2000)
mock.run_command("/yt-chat", "splitA", "https://www.youtube.com/@test/live")
T.eq(mock.count_requests("get_live_chat"), polls_after_end + 1, "polling restarted")
local reqs_before = mock.count_requests("get_live_chat")
mock.advance(31000) -- backoff for first error is ~2 s, then poll resumes
T.ok(mock.count_requests("get_live_chat") > reqs_before, "retry after transient error")
T.ok(mock.channels.splitA.messages[#mock.channels.splitA.messages].message_text:find("after reconnect", 1, true) ~= nil,
  "polling recovered after transient error")
mock.http_responder = base_responder

-- Offline channel -> live detection via offline monitor ----------------------

live = false
mock.run_command("/yt-chat", "splitA", "https://www.youtube.com/@offline/live")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("offline", 1, true) ~= nil,
  "offline registration announced")

live = true
payload_queue[1] = chat_payload({ text_action("m9", "erin", "we are live") }, 2000)
mock.advance(31000) -- offline monitor interval (30 s first attempt)
T.ok(mock.count_requests("get_live_chat") > polls_after_end, "offline monitor detected live stream")
T.ok(#mock.channels.splitA.messages >= 5, "live chat resumed after detection")

os.execute("rm -rf " .. test_dir)
