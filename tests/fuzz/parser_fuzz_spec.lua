local T = require("tests.test_runner")
local Actions = require("src.youtube.actions")

local corpus = {
  {},
  { addChatItemAction = {} },
  { addChatItemAction = { item = { liveChatTextMessageRenderer = { id = 1, message = { runs = { { emoji = {} } } } } } } },
  { addChatItemAction = { item = { strangeRenderer = { deep = { arr = { nil, 1, "x" } } } } } },
  { markChatItemAsDeletedAction = { targetItemId = string.rep("a", 2048) } }
}

for _, entry in ipairs(corpus) do
  local ok = pcall(function()
    Actions.from_action(entry)
  end)
  T.ok(ok, "fuzz parser should not crash")
end
