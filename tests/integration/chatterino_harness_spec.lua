local T = require("tests.test_runner")
local Builder = require("src.messages.builder")

_G.c2 = {
  FontStyle = { ChatMediumBold = "bold", Tiny = "tiny" },
  Message = {
    new = function(payload)
      return payload
    end
  }
}

local msg = Builder.to_chatterino_message({
  kind = "super_sticker",
  amount = "€2.00",
  author = "user"
}, true)

T.ok(msg.message_text:find("Super Sticker", 1, true) ~= nil, "integration message render")
