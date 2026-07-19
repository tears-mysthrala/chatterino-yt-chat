local T = require("tests.test_runner")
local Url = require("src.youtube.url")

local n1 = Url.normalize("https://www.youtube.com/watch?v=abc123")
T.eq(n1.kind, "video", "watch kind")
T.eq(n1.video_id, "abc123", "watch id")

local n2 = Url.normalize("https://youtu.be/xyz987")
T.eq(n2.kind, "video", "short kind")
T.eq(n2.video_id, "xyz987", "short id")

local n3 = Url.normalize("https://www.youtube.com/@channel/live")
T.eq(n3.kind, "channel_handle", "handle kind")

local _, e = Url.normalize("http://evil.local/watch?v=x")
T.eq(e, "invalid_url", "invalid host")
