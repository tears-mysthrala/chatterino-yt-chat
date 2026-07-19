local T = require("tests.test_runner")
local C = require("src.youtube.continuations")

local payload = {
  continuationContents = {
    liveChatContinuation = {
      continuations = {
        {
          timedContinuationData = {
            continuation = "ABC",
            timeoutMs = 2500
          }
        }
      }
    }
  }
}

local out, err = C.pick(payload)
T.eq(err, nil, "no continuation error")
T.eq(out.token, "ABC", "continuation token")
T.eq(out.timeout_ms, 2500, "continuation timeout")

local missing, err2 = C.pick({})
T.eq(missing, nil, "missing continuation object")
T.eq(err2, "missing_continuation", "missing continuation error")
