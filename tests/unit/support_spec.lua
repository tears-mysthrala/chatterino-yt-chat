local T = require("tests.test_runner")
local Validation = require("src.support.validation")
local RateLimit = require("src.support.rate_limit")
local Backoff = require("src.support.backoff")
local Logging = require("src.support.logging")

-- validation: hosts
T.ok(Validation.is_safe_https_youtube("https://www.youtube.com/watch?v=abc"), "youtube https ok")
T.ok(not Validation.is_safe_https_youtube("http://www.youtube.com/watch?v=abc"), "http rejected")
T.ok(not Validation.is_safe_https_youtube("https://evil-youtube.com/x"), "foreign host rejected")
T.ok(not Validation.is_safe_https_youtube("https://www.youtube.com.evil.com/x"), "suffix host rejected")
T.ok(Validation.is_safe_https_youtube("https://youtu.be/abc"), "youtu.be ok")

-- validation: image hosts
T.ok(Validation.is_safe_image_url("https://yt3.ggpht.com/abc/image.png"), "ggpht image ok")
T.ok(Validation.is_safe_image_url("https://i.ytimg.com/vi/x/default.jpg"), "ytimg image ok")
T.ok(not Validation.is_safe_image_url("https://www.youtube.com/x.png"), "youtube.com not image host")
T.ok(not Validation.is_safe_image_url("http://yt3.ggpht.com/x.png"), "image http rejected")
T.ok(not Validation.is_safe_image_url("https://attacker.com/x.png"), "foreign image host rejected")

-- validation: sanitize_text
T.eq(Validation.sanitize_text(nil), "", "sanitize nil -> empty")
T.eq(Validation.sanitize_text(42), "", "sanitize number -> empty")
T.eq(Validation.sanitize_text("hola\0mundo"), "holamundo", "control chars stripped")
T.eq(Validation.sanitize_text("a\tb\nc"), "a\tb\nc", "tab/newline kept")
T.eq(#Validation.sanitize_text(string.rep("x", 5000)), 4000, "text truncated at 4000")
T.eq(#Validation.sanitize_text(string.rep("x", 100), 10), 10, "custom limit")

-- validation: sanitize_id
T.eq(Validation.sanitize_id("UCabc-123_=."), "UCabc-123_=.", "id charset kept")
T.eq(Validation.sanitize_id("UC bad id!"), "UCbadid", "id junk stripped")
T.eq(Validation.sanitize_id("!!!"), nil, "empty after strip -> nil")
T.eq(Validation.sanitize_id(nil), nil, "nil id -> nil")

-- validation: colors / retry-after
T.ok(Validation.is_valid_color(0), "color 0 ok")
T.ok(Validation.is_valid_color(4294967295), "color max ok")
T.ok(not Validation.is_valid_color(-1), "color negative rejected")
T.ok(not Validation.is_valid_color("red"), "color string rejected")
T.eq(Validation.parse_retry_after("5"), 5, "retry-after string")
T.eq(Validation.parse_retry_after(nil), nil, "retry-after nil")
T.eq(Validation.parse_retry_after(-3), nil, "retry-after negative")

-- rate_limit: window behavior with injected clock
do
  local now = 100000
  RateLimit._now = function() return now end
  RateLimit._clear()
  T.ok(RateLimit.allow("k1", 1000, 2), "first hit allowed")
  T.ok(RateLimit.allow("k1", 1000, 2), "second hit allowed")
  T.ok(not RateLimit.allow("k1", 1000, 2), "third hit blocked")
  now = now + 1001
  T.ok(RateLimit.allow("k1", 1000, 2), "window reset allows again")
end

-- rate_limit: bucket eviction cap
do
  local now = 100000
  RateLimit._now = function() return now end
  RateLimit._clear()
  for i = 1, 300 do
    RateLimit.allow("flood-" .. i, 60000, 1)
  end
  T.ok(RateLimit._size() <= 256, "buckets bounded at 256")
  RateLimit._clear()
end

-- backoff: offline schedule with jitter forced to 0
do
  Backoff._random = function() return 0 end
  T.eq(Backoff.offline_attempt_delay(1), 30, "offline attempt 1 = 30s")
  T.eq(Backoff.offline_attempt_delay(2), 60, "offline attempt 2 = 60s")
  T.eq(Backoff.offline_attempt_delay(3), 120, "offline attempt 3 = 120s")
  T.eq(Backoff.offline_attempt_delay(4), 300, "offline attempt 4 = 300s")
  T.eq(Backoff.offline_attempt_delay(99), 300, "offline capped at 300s")
  T.eq(Backoff.chat_error_delay(1), 2, "chat error exp base")
  T.eq(Backoff.chat_error_delay(99), 30, "chat error capped at 30s")
  T.eq(Backoff.chat_error_delay(1, 10), 10, "retry-after honored")
  T.eq(Backoff.chat_error_delay(1, 3600), 30, "retry-after capped at 30s")
  Backoff._random = math.random
end

-- logging: redaction + capture via print override
do
  local lines = {}
  local real_print = print
  _G.print = function(s) lines[#lines + 1] = tostring(s) end

  Logging.error("redaction_test", {
    continuation = "SECRET-TOKEN-VALUE",
    api_key = "KEY-VALUE",
    note = "visible"
  })
  local line = lines[#lines]
  T.ok(line:find("SECRET%-TOKEN%-VALUE") == nil, "continuation redacted")
  T.ok(line:find("KEY%-VALUE") == nil, "api key redacted")
  T.ok(line:find("visible", 1, true) ~= nil, "safe field visible")

  -- dedupe: 3 emits + 1 summary, then dropped
  lines = {}
  for _ = 1, 10 do
    Logging.warning("dedupe_test_msg")
  end
  local real_count, summary_count = 0, 0
  for _, l in ipairs(lines) do
    if l:find("suppressed repeated", 1, true) then
      summary_count = summary_count + 1
    elseif l:find("dedupe_test_msg", 1, true) then
      real_count = real_count + 1
    end
  end
  T.eq(real_count, 3, "dedupe allows 3 emits")
  T.eq(summary_count, 1, "dedupe emits one summary")

  _G.print = real_print
end

-- logging: deep redaction for samples
do
  local redacted = Logging.redact_deep({
    a = { continuation = "xyz", nested = { cookie = "c", keep = 1 } },
    list = { { token = "t", ok = "v" } }
  })
  T.eq(redacted.a.continuation, "<redacted>", "deep continuation redacted")
  T.eq(redacted.a.nested.cookie, "<redacted>", "deep cookie redacted")
  T.eq(redacted.a.nested.keep, 1, "non-sensitive kept")
  T.eq(redacted.list[1].token, "<redacted>", "array token redacted")
  T.eq(redacted.list[1].ok, "v", "array value kept")
end

-- logging: c2.log used when available
do
  local logged = {}
  _G.c2 = {
    LogLevel = { Critical = "C", Warning = "W", Info = "I", Debug = "D" },
    log = function(level, line) logged[#logged + 1] = { level = level, line = line } end
  }
  Logging.error("c2_route_test")
  T.eq(#logged, 1, "c2.log called")
  T.eq(logged[1].level, "C", "error maps to Critical")
  _G.c2 = nil
end
