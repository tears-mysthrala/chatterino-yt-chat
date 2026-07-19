local Text = {}

local function parse_runs(runs)
  if type(runs) ~= "table" then
    return "", {}
  end
  local chunks = {}
  local items = {}
  for _, run in ipairs(runs) do
    if type(run) == "table" then
      if type(run.text) == "string" then
        table.insert(chunks, run.text)
        table.insert(items, { type = "text", value = run.text })
      elseif run.emoji then
        local label = run.emoji.shortcuts and run.emoji.shortcuts[1] or run.emoji.emojiId or "[emoji]"
        table.insert(chunks, label)
        table.insert(items, { type = "emoji", value = label, emoji = run.emoji })
      elseif run.navigationEndpoint and run.navigationEndpoint.commandMetadata then
        local url = run.navigationEndpoint.commandMetadata.webCommandMetadata and
            run.navigationEndpoint.commandMetadata.webCommandMetadata.url or ""
        local shown = run.text or url
        table.insert(chunks, shown)
        table.insert(items, { type = "link", value = shown, url = url })
      else
        table.insert(items, { type = "unknown_run", value = "[unknown-run]" })
      end
    end
  end
  return table.concat(chunks), items
end

function Text.from_text_renderer(renderer)
  local author = renderer.authorName and (renderer.authorName.simpleText or renderer.authorName.text) or "[YouTube user]"
  local runs = renderer.message and renderer.message.runs or {}
  local text, parsed_runs = parse_runs(runs)
  return {
    kind = "text",
    message_id = renderer.id,
    author = author,
    author_badges = renderer.authorBadges or {},
    timestamp_usec = renderer.timestampUsec,
    text = text,
    runs = parsed_runs
  }
end

return Text
