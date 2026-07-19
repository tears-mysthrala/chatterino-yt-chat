#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

lua - <<'LUA'
package.path = "./?.lua;./?/init.lua;" .. package.path

local runner = require("tests.test_runner")
local specs = {
  "tests.unit.url_spec",
  "tests.unit.continuations_spec",
  "tests.unit.actions_renderers_spec",
  "tests.unit.support_spec",
  "tests.unit.persistence_spec",
  "tests.unit.state_spec",
  "tests.integration.chatterino_harness_spec",
  "tests.fuzz.parser_fuzz_spec",
  "tests.perf.load_spec"
}

for _, mod in ipairs(specs) do
  local ok, err = pcall(require, mod)
  if not ok then
    io.stderr:write("FAILED " .. mod .. ": " .. tostring(err) .. "\n")
    os.exit(1)
  end
end

local assertions, failures = runner.summary()
print(string.format("Assertions: %d, Failures: %d", assertions, failures))
if failures > 0 then
  os.exit(1)
end
LUA
