local failures = 0
local assertions = 0

local M = {}

function M.eq(actual, expected, label)
  assertions = assertions + 1
  if actual ~= expected then
    failures = failures + 1
    error((label or "assertion failed") .. " expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
  end
end

function M.ok(value, label)
  assertions = assertions + 1
  if not value then
    failures = failures + 1
    error(label or "expected truthy")
  end
end

function M.summary()
  return assertions, failures
end

return M
