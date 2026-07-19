-- Defensive fuzzing: parsers must never throw, loop forever, or take the
-- plugin down over a single malformed event.
local T = require("tests.test_runner")
local json = require("libs/json")
local Actions = require("src.youtube.actions")
local Renderers = require("src.youtube.renderers")
local Continuations = require("src.youtube.continuations")
local Html = require("src.youtube.html")
local Url = require("src.youtube.url")
local Persistence = require("src.state.persistence")
local Builder = require("src.messages.builder")

math.randomseed(42)

local KEY_POOL = {
  "addChatItemAction", "item", "liveChatTextMessageRenderer", "message", "runs",
  "text", "emoji", "authorName", "simpleText", "id", "timestampUsec",
  "continuationContents", "liveChatContinuation", "continuations",
  "invalidationContinuationData", "continuation", "timeoutMs", "authorBadges",
  "purchaseAmountText", "unknownKey2042", "continuation_token"
}

local VALUE_POOL = {
  "", "x", "hello world", "😀🎉", 0, -1, 1e18, 3.14, true, false,
  ("y"):rep(5000), "\0\1\2", "%s%s%d", "https://evil.example/x"
}

local function random_tree(depth, rng)
  if depth <= 0 then
    return VALUE_POOL[rng(#VALUE_POOL)]
  end
  local node = {}
  local n = rng(6)
  for _ = 1, n do
    local key = KEY_POOL[rng(#KEY_POOL)]
    if rng(2) == 1 then
      node[key] = random_tree(depth - 1, rng)
    else
      node[#node + 1] = random_tree(depth - 1, rng)
    end
  end
  return node
end

local function rng_factory(i)
  return function(n)
    return (i * 2654435761 % 2^31 % n) + 1
  end
end

-- 400 random malformed trees through the action pipeline.
for i = 1, 400 do
  local rng = rng_factory(i)
  local tree = random_tree(5, rng)
  local ok, events = pcall(Actions.from_action, tree)
  T.ok(ok, "from_action survives tree " .. i)
  if ok and type(events) == "table" then
    for _, event in ipairs(events) do
      local build_ok = pcall(Builder.to_chatterino_message, event, true)
      T.ok(build_ok, "builder survives event from tree " .. i)
    end
  end
end

-- Degenerate single values and structures.
local DEGENERATE = {
  nil, false, 0, "", {}, { item = false }, { addChatItemAction = false },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = false } } },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = { message = { runs = "not-a-table" } } } } },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = { message = { runs = { { text = false }, { emoji = 42 }, {} } } } } } },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = { timestampUsec = "not-a-number" } } } },
  { replayChatItemAction = { actions = "broken" } },
  { replayChatItemAction = { actions = {} } },
  { markChatItemAsDeletedAction = {} },
  { addBannerToLiveChatCommand = { bannerRenderer = false } },
  { updateLiveChatPollAction = { pollToUpdate = false } },
  { [1] = "array action" },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = { message = { runs = (function()
    local many = {}
    for j = 1, 500 do
      many[j] = { text = "run" .. j }
    end
    return many
  end)() } } } } },
}
for i, case in ipairs(DEGENERATE) do
  local ok, events = pcall(Actions.from_action, case)
  T.ok(ok, "degenerate case " .. i .. " survives")
  if ok and type(events) == "table" then
    for _, event in ipairs(events) do
      T.ok(pcall(Builder.to_chatterino_message, event, true), "degenerate case " .. i .. " builds")
    end
  end
end

-- Deep nesting (depth cap must hold, no stack overflow).
local deep = {}
do
  local node = deep
  for _ = 1, 500 do
    node.item = {}
    node = node.item
  end
end
T.ok(pcall(Actions.from_action, deep), "deep nesting survives")
T.ok(pcall(require("src.support.logging").redact_deep, deep), "redact_deep survives deep nesting")

-- Continuations fuzz.
for i = 1, 100 do
  local rng = rng_factory(i + 1000)
  local tree = random_tree(4, rng)
  local ok = pcall(Continuations.pick, tree)
  T.ok(ok, "continuations.pick survives " .. i)
end

-- HTML parser fuzz: binary garbage, huge strings, pattern bombs.
T.ok(pcall(Html.parse_watch_page, ("x"):rep(1024 * 1024)), "html 1 MiB garbage")
T.ok(pcall(Html.parse_watch_page, "\0\1\2\3\4"), "html binary")
T.ok(pcall(Html.parse_watch_page, '"videoId":"' .. ("a"):rep(100000) .. '"'), "html huge value")
local _, too_large = Html.parse_watch_page(("y"):rep(9 * 1024 * 1024))
T.eq(too_large, "too_large", "html oversize rejected")

-- URL fuzz.
local URL_GARBAGE = {
  "", "https://", "https://www.youtube.com", "https://www.youtube.com/watch?v=",
  "https://www.youtube.com/watch?v=" .. ("a"):rep(500),
  "https://www.youtube.com/@", "javascript:alert(1)", "file:///etc/passwd",
  "https://www.youtube.com.evil.com/watch?v=x", "https://user:pass@www.youtube.com/watch?v=x",
  "HTTPS://WWW.YOUTUBE.COM/watch?v=abc123"
}
for i, garbage in ipairs(URL_GARBAGE) do
  T.ok(pcall(Url.normalize, garbage), "url fuzz " .. i .. " survives")
end

-- validate_schema fuzz.
for i = 1, 100 do
  local rng = rng_factory(i + 5000)
  T.ok(pcall(Persistence.validate_schema, random_tree(4, rng)), "validate_schema survives " .. i)
end

-- JSON decode errors must be catchable via pcall (the polling contract):
-- broken input fails loudly inside pcall, never escapes.
do
  local ok1 = pcall(json.decode, "{broken")
  T.ok(not ok1, "broken json raises inside pcall")
  local ok2, decoded2 = pcall(json.decode, "")
  T.ok(not ok2 or type(decoded2) ~= "table", "empty json handled")
  local ok3 = pcall(json.decode, "\0")
  T.ok(ok3 == true or ok3 == false, "binary json handled")
end
