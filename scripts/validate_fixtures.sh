#!/usr/bin/env bash
# Validates every JSON fixture: parses cleanly, and every action fixture
# produces at least one event (or is a documented no-op).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LUA_BIN="${LUA_BIN:-$(command -v lua || command -v lua5.4 || command -v luajit)}"

"$LUA_BIN" - <<'LUA'
package.path = "./?.lua;./?/init.lua;" .. package.path
local json = require("libs/json")
local Actions = require("src.youtube.actions")

local NOOP = {
  ["fixtures/synthetic/liveChatReportModerationStateCommand.json"] = true
}

local checked, failed = 0, 0
local function check(path)
  local f = io.open(path, "r")
  if not f then
    return
  end
  local raw = f:read("a")
  f:close()
  local ok, decoded = pcall(json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    io.stderr:write("INVALID JSON: " .. path .. "\n")
    failed = failed + 1
    return
  end
  checked = checked + 1
  if path:find("/actions/") or path:find("/synthetic/") or path:find("/real/") then
    local events = Actions.from_action(decoded)
    if NOOP[path] then
      if #events ~= 0 then
        io.stderr:write("EXPECTED NO-OP BUT GOT EVENTS: " .. path .. "\n")
        failed = failed + 1
      end
    elseif #events == 0 then
      io.stderr:write("NO EVENTS FROM: " .. path .. "\n")
      failed = failed + 1
    end
  end
end

local function scan(dir)
  local p = io.popen('ls "' .. dir .. '" 2>/dev/null')
  if not p then
    return
  end
  for name in p:lines() do
    if name:match("%.json$") then
      check(dir .. "/" .. name)
    end
  end
  p:close()
end

scan("fixtures/actions")
scan("fixtures/continuations")
scan("fixtures/errors")
scan("fixtures/renderers")
scan("fixtures/real")
scan("fixtures/synthetic")

print(string.format("Fixtures checked: %d, failures: %d", checked, failed))
if failed > 0 then
  os.exit(1)
end
LUA
