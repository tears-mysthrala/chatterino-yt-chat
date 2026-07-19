local T = require("tests.test_runner")
local Actions = require("src.youtube.actions")

local text_action = {
  addChatItemAction = {
    item = {
      liveChatTextMessageRenderer = {
        id = "m1",
        authorName = { simpleText = "alice" },
        message = { runs = { { text = "hello" }, { text = " world" } } }
      }
    }
  }
}

local ev = Actions.from_action(text_action)
T.eq(ev.kind, "text", "text renderer kind")
T.eq(ev.text, "hello world", "text renderer message")

local paid = {
  addChatItemAction = {
    item = {
      liveChatPaidMessageRenderer = {
        id = "m2",
        authorName = { simpleText = "bob" },
        purchaseAmountText = { simpleText = "$5.00" },
        message = { runs = { { text = "thanks" } } }
      }
    }
  }
}
local paid_ev = Actions.from_action(paid)
T.eq(paid_ev.kind, "super_chat", "super chat kind")
T.eq(paid_ev.amount, "$5.00", "super chat amount")

local unknown = Actions.from_action({ unknownAction = { value = true } })
T.eq(unknown.kind, "unknown_event", "unknown action fallback")
