-- luacheck configuration for chatterino-yt-chat
std = "lua54"

globals = {
  "c2" -- Chatterino plugin API global
}

exclude_files = {
  "libs/", -- vendored library
  "dist/"
}

-- Test files use the same globals plus the test harness
files["tests/"] = {
  globals = { "c2" }
}

-- The plugin intentionally avoids os/io outside persistence/validation;
-- unused function arguments are common in callbacks.
ignore = {
  "212", -- unused argument
  "213" -- unused loop variable
}

max_line_length = 140
