local T = require("tests.test_runner")
local Url = require("src.youtube.url")

-- /watch?v=
local n1 = Url.normalize("https://www.youtube.com/watch?v=abc123")
T.eq(n1.kind, "video", "watch kind")
T.eq(n1.video_id, "abc123", "watch id")
T.eq(n1.canonical, "https://www.youtube.com/watch?v=abc123", "watch canonical")

-- /watch with extra innocuous params
local n1b = Url.normalize("https://www.youtube.com/watch?v=abc123&t=42&list=PLxyz")
T.eq(n1b.video_id, "abc123", "extra params tolerated")

-- youtu.be short URL
local n2 = Url.normalize("https://youtu.be/xyz987")
T.eq(n2.kind, "video", "short kind")
T.eq(n2.video_id, "xyz987", "short id")

-- youtu.be with params
local n2b = Url.normalize("https://youtu.be/xyz987?t=10")
T.eq(n2b.video_id, "xyz987", "short id with params")

-- /live/<videoId>
local n3 = Url.normalize("https://www.youtube.com/live/abcDEF123-_")
T.eq(n3.kind, "video", "live kind")
T.eq(n3.video_id, "abcDEF123-_", "live video id")

-- /channel/<id>
local n4 = Url.normalize("https://www.youtube.com/channel/UCabc123def")
T.eq(n4.kind, "channel", "channel kind")
T.eq(n4.channel_id, "UCabc123def", "channel id")
T.eq(n4.canonical, "https://www.youtube.com/channel/UCabc123def/live", "channel canonical /live")

-- /channel/<id>/live tab
local n4b = Url.normalize("https://www.youtube.com/channel/UCabc123def/live")
T.eq(n4b.channel_id, "UCabc123def", "channel /live tab")

-- /@handle
local n5 = Url.normalize("https://www.youtube.com/@SomeHandle")
T.eq(n5.kind, "channel_handle", "handle kind")
T.eq(n5.handle, "SomeHandle", "handle value")
T.eq(n5.canonical, "https://www.youtube.com/@SomeHandle/live", "handle canonical /live")

-- /@handle/live tab
local n5b = Url.normalize("https://www.youtube.com/@SomeHandle/live")
T.eq(n5b.handle, "SomeHandle", "handle /live tab")

-- Bare @handle shorthand
local n5c = Url.normalize("@SomeHandle")
T.eq(n5c.kind, "channel_handle", "bare handle kind")
T.eq(n5c.handle, "SomeHandle", "bare handle value")
T.eq(n5c.canonical, "https://www.youtube.com/@SomeHandle/live", "bare handle canonical /live")

-- m.youtube.com host
local n6 = Url.normalize("https://m.youtube.com/watch?v=mobi123")
T.eq(n6.video_id, "mobi123", "mobile host ok")

-- rejections
local _, e1 = Url.normalize("http://www.youtube.com/watch?v=abc123")
T.eq(e1, "invalid_url", "http rejected")
local _, e2 = Url.normalize("https://evil.example/watch?v=abc123")
T.eq(e2, "invalid_url", "foreign host rejected")
local _, e3 = Url.normalize("https://www.youtube.com.evil.com/watch?v=abc123")
T.eq(e3, "invalid_url", "host suffix attack rejected")
local _, e4 = Url.normalize("https://www.youtube.com/playlist?list=PL123")
T.eq(e4, "unsupported_url", "playlist unsupported")
local _, e5 = Url.normalize("https://www.youtube.com/watch")
T.eq(e5, "unsupported_url", "watch without v unsupported")
local _, e6 = Url.normalize("not a url")
T.eq(e6, "invalid_url", "garbage rejected")
local _, e7 = Url.normalize("https://www.youtube.com/watch?v=a b")
T.eq(e7, "invalid_video_id", "spaces in video id rejected")
local _, e8 = Url.normalize("https://youtu.be/")
T.eq(e8, "unsupported_url", "empty short id rejected")
local _, e9 = Url.normalize("@bad handle")
T.eq(e9, "invalid_url", "invalid bare handle rejected")
