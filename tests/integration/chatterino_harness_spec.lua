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

-- Future image API: declarative remote images materialize only when the
-- verified Chatterino capability exists; stable 2.5.5 keeps text fallback.
do
  local Adapter = require("src.c2_adapter")
  mock.c2.MessageElementFlag = { AlwaysShow = 1, EmoteImage = 2 }
  mock.c2.Image = { from_url = function(url) return { url = url } end }
  Adapter.deliver({
    message_text = "image probe",
    elements = { { type = "remote-image", url = "https://yt3.ggpht.com/avatar", circular = true } }
  }, { "splitA" })
  local probe = mock.channels.splitA.messages[#mock.channels.splitA.messages]
  T.eq(probe.elements[1].type, "circular-image", "future image capability materializes avatar")
  T.eq(probe.elements[1].image.url, "https://yt3.ggpht.com/avatar", "future image keeps validated URL")
  table.remove(mock.channels.splitA.messages)
  mock.c2.Image = nil
  mock.c2.MessageElementFlag = nil
  Adapter.deliver({
    message_text = "text-only image fallback",
    elements = { { type = "remote-image", url = "https://yt3.ggpht.com/avatar", circular = true } }
  }, { "splitA" })
  local fallback = mock.channels.splitA.messages[#mock.channels.splitA.messages]
  T.eq(fallback.message_text, "text-only image fallback", "stable API retains textual fallback")
  T.eq(#fallback.elements, 0, "stable API does not leak unsupported image elements")
  table.remove(mock.channels.splitA.messages)
end
T.ok(mock.commands["/yt-chat"] ~= nil, "command registered")
T.ok(mock.callbacks[mock.c2.EventType.CompletionRequested] ~= nil, "command completion registered")
local completions = mock.callbacks[mock.c2.EventType.CompletionRequested]({
  query = "sta", full_text_content = "/yt-chat sta", cursor_position = 12, is_first_word = false
})
T.eq(completions.values[1], "status", "international status command completion offered")
mock.run_command("/yt-chat", "splitA", "ayuda")
local international_help = mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]
for _, usage in ipairs({ "help", "auto [@usuario]", "list", "status", "health [export]", "pause <canal>",
    "resume <canal>", "remove <canal>", "delay [0-30000]", "lang [es|en]", "config [gui]", "export", "import" }) do
  T.ok(international_help:find(usage, 1, true) ~= nil, "Spanish help documents " .. usage)
end
mock.run_command("/yt-chat", "splitA", "configurar", "interfaz", "sí")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("no permite", 1, true) ~= nil,
  "GUI activation attempt explains the upstream limitation")
mock.run_command("/yt-chat", "splitA", "pausar")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find(
  "/yt-chat pausar <canal>", 1, true) ~= nil,
  "localized channel controls preserve their alias in usage errors")
mock.run_command("/yt-chat", "splitA", "status")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("directo(s)", 1, true) ~= nil,
  "English command aliases remain accepted in Spanish mode")
mock.add_channel("not a handle")
local requests_before_invalid_auto = #mock.requests
mock.run_command("/yt-chat", "not a handle", "auto")
T.eq(#mock.requests, requests_before_invalid_auto, "invalid inferred handle does not issue a request")
T.ok(mock.channels["not a handle"].system_messages[#mock.channels["not a handle"].system_messages]:find(
  "URL no válida", 1, true) ~= nil, "invalid inferred handle reports a safe validation error")
mock.remove_channel("not a handle")

-- Runtime sync delay setting is validated, persisted and immediately active.
mock.run_command("/yt-chat", "splitA", "delay", "750")
T.eq(Plugin._state().settings.chat_sync_delay_ms, 750, "sync delay persisted in state")
T.eq(require("src.youtube.polling").get_sync_delay(), 750, "sync delay active immediately")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("▶️ YT", 1, true) == 1,
  "plugin system messages carry YouTube emoji prefix")
mock.run_command("/yt-chat", "splitA", "delay")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("750 ms", 1, true) ~= nil,
  "sync delay command reports current value")
mock.run_command("/yt-chat", "splitA", "delay", "30001")
T.eq(require("src.youtube.polling").get_sync_delay(), 750, "invalid sync delay leaves current value unchanged")

-- Import invalidates URL callbacks that started against the previous state.
Persistence.export_snapshot(Plugin._state())
mock.defer_http = true
mock.run_command("/yt-chat", "splitA", "https://www.youtube.com/@offline/live")
mock.run_command("/yt-chat", "splitA", "import")
mock.flush_http()
mock.defer_http = false
T.eq(Plugin._state().channels["UCFAKECHANNEL0000000002"], nil,
  "stale URL callback cannot restore a channel removed by import")

-- If rich c2.Message construction is unavailable, textual fallback still
-- identifies the message as originating from YouTube.
do
  local message_new = mock.c2.Message.new
  mock.c2.Message.new = nil
  local fallback_spec = require("src.messages.builder").to_chatterino_message({
    kind = "text_message",
    author = "fallback-user",
    text = "fallback body"
  }, false)
  require("src.c2_adapter").deliver(fallback_spec, { "splitA" })
  local fallback_text = mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]
  T.ok(fallback_text:find("▶️ YT ", 1, true) == 1, "degraded delivery keeps YouTube prefix")
  mock.c2.Message.new = message_new
end

-- Add a live channel from splitA ---------------------------------------------

payload_queue[1] = chat_payload({
  text_action("m1", "alice", "hello chat"),
  text_action("m2", "bob", "second message")
}, 2000)

mock.run_command("/yt-chat", "splitA", "auto")
T.eq(mock.count_requests("get_live_chat"), 1, "polling started immediately")
T.eq(Plugin._state().channels.UCFAKECHANNEL0000000001.handle, "splitA",
  "argument-free auto infers and persists the current conversation name")
local inferred_handle_requested = false
for _, request in ipairs(mock.requests) do
  if request.url:find("youtube.com/@splitA/live", 1, true) then inferred_handle_requested = true end
end
T.ok(inferred_handle_requested, "argument-free auto resolves the inferred YouTube handle")
T.eq(#mock.channels.splitA.messages, 0, "initial messages wait for presentation delay")

-- Multi-split: same channel added from splitB — no duplicate polling --------

mock.run_command("/yt-chat", "splitB", "auto", "@test")
T.ok(mock.requests[#mock.requests].url:find("youtube.com/@test/live", 1, true) ~= nil,
  "explicit auto override uses the supplied YouTube handle")
T.eq(mock.count_requests("get_live_chat"), 1, "no second polling for same video")
mock.run_command("/yt-chat", "splitA", "status")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("próximo sondeo", 1, true) ~= nil,
  "status command reports active stream timing")
mock.run_command("/yt-chat", "splitA", "list")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("Test Channel", 1, true) ~= nil,
  "list command reports configured channel")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("panel(es)", 1, true) ~= nil,
  "Spanish channel list avoids untranslated split labels")
mock.run_command("/yt-chat", "splitA", "health")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("solicitudes", 1, true) ~= nil,
  "health command reports content-free counters")
mock.run_command("/yt-chat", "splitA", "lang", "en")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("Language", 1, true) ~= nil,
  "language can be changed live")
mock.run_command("/yt-chat", "splitA", "health", "export")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("Diagnostics exported", 1, true) ~= nil,
  "diagnostics export follows selected language")
mock.run_command("/yt-chat", "splitA", "help")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("Commands", 1, true) ~= nil,
  "help follows selected language")
mock.run_command("/yt-chat", "splitA", "lang", "es")
mock.advance(749)
T.eq(#mock.channels.splitA.messages, 0, "presentation delay has not elapsed")
mock.advance(1)
T.eq(#mock.channels.splitA.messages, 0, "initial history remains hidden after presentation delay")
T.eq(#mock.channels.splitB.messages, 0, "new split does not receive initial history")
mock.run_command("/yt-chat", "splitA", "health")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("lotes 0", 1, true) ~= nil,
  "skipped initial history is not counted as a delivered batch")

payload_queue[1] = chat_payload({ text_action("m3", "carol", "after split join") }, 2000)
mock.advance(1250)
T.eq(mock.count_requests("get_live_chat"), 2, "next poll scheduled by YouTube timeout")
T.eq(#mock.channels.splitA.messages, 0, "polling does not bypass presentation delay")
mock.advance(750)
T.eq(#mock.channels.splitB.messages, 1, "new message distributed to splitB")
T.eq(#mock.channels.splitA.messages, 1, "new message also in splitA")
T.eq(mock.channels.splitA.messages[1].id, "yt-chat-m3", "live message id prefixed")

-- Dedupe: re-delivered id is dropped -----------------------------------------

payload_queue[1] = chat_payload({
  text_action("m3", "carol", "after split join"),
  text_action("m4", "dan", "fresh")
}, 2000)
mock.advance(2000)
T.eq(#mock.channels.splitA.messages, 2, "duplicate id not rendered again")

-- Moderation: in-place deletion ----------------------------------------------

payload_queue[1] = chat_payload({
  { markChatItemAsDeletedAction = { targetItemId = "m3", deletedStateMessage = { runs = { { text = "Message deleted by moderator" } } } } }
}, 2000)
mock.advance(2000)
local replaced = mock.channels.splitA.messages[1]
T.ok(replaced.message_text:find("deleted", 1, true) ~= nil, "original message replaced by deletion marker")
T.eq(replaced.elements[1].text, "▶️", "moderation replacement keeps YouTube emoji prefix")
T.eq(#mock.channels.splitA.messages, 2, "deletion does not append a new message")

-- Unknown action produces a visible system event -----------------------------

payload_queue[1] = chat_payload({ { brandNewAction2042 = { weird = true } } }, 2000)
mock.advance(2000)
local last_sys = mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]
T.ok(last_sys:find("brandNewAction2042", 1, true) ~= nil, "unknown action visible in chat")

-- Stream end: no continuationContents -> stop + cleanup -----------------------

payload_queue[1] = json.encode({ responseContext = {} })
mock.advance(2000)
T.eq(ActiveStreams.active_video_count(), 0, "stream cleaned after end")
T.ok(mock.channels.splitA.system_messages[#mock.channels.splitA.system_messages]:find("finalizado", 1, true) ~= nil,
  "stream end announced")
local polls_after_end = mock.count_requests("get_live_chat")
mock.advance(10000)
T.eq(mock.count_requests("get_live_chat"), polls_after_end, "no polling after stream end")

-- Reconnection: transient HTTP 500 -> bounded backoff retry -> recovery ----

live = true
local fail_next = 1
local reconnect_successes = 0
local base_responder = mock.http_responder
mock.http_responder = function(method, url, payload)
  if fail_next > 0 and url:find("get_live_chat", 1, true) then
    fail_next = fail_next - 1
    return { status = 500, data = "" }
  end
  if url:find("get_live_chat", 1, true) then
    reconnect_successes = reconnect_successes + 1
    local event = reconnect_successes == 1 and
        text_action("m8", "zoe", "historical reconnect message") or
        text_action("m10", "zoe", "after reconnect")
    return { status = 200, data = chat_payload({ event }, 2000) }
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
local offline_watch_url = "youtube.com/channel/UCFAKECHANNEL0000000002/live"
local offline_checks = mock.count_requests(offline_watch_url)
mock.advance(29000)
T.eq(mock.count_requests(offline_watch_url), offline_checks,
  "new offline binding is not checked before its 30 second cadence")

live = true
payload_queue[1] = chat_payload({ text_action("m9", "erin", "we are live") }, 2000)
mock.advance(1000) -- scheduled first check at exactly 30 s
T.eq(mock.count_requests(offline_watch_url), offline_checks + 1,
  "new offline binding is checked after 30 seconds even if the global monitor was sleeping")
T.ok(mock.count_requests("get_live_chat") > polls_after_end, "offline monitor detected live stream")
payload_queue[1] = chat_payload({ text_action("m11", "erin", "new after detection") }, 2000)
mock.advance(2750)
T.ok(mock.channels.splitA.messages[#mock.channels.splitA.messages].message_text:find(
  "new after detection", 1, true) ~= nil, "live chat resumed without rendering initial history")

os.execute("rm -rf " .. test_dir)
