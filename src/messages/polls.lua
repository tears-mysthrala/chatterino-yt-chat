local Common = require("src.messages.common")
local Emotes = require("src.messages.emotes")

local Polls = {}

local function parse_choices(choices)
  local options = {}
  if type(choices) ~= "table" then
    return options
  end
  for _, choice in ipairs(choices) do
    local renderer = type(choice) == "table" and
        (choice.liveChatPollChoiceRenderer or choice.pollChoiceRenderer or choice) or nil
    if renderer then
      local text = Common.safe_text(Common.runs_flat(renderer.text or renderer.label), 200)
      if text then
        options[#options + 1] = {
          text = text,
          votes = tonumber(renderer.voteCount) or nil,
          ratio = tonumber(renderer.voteRatio) or nil
        }
      end
    end
  end
  return options
end

local function metadata_votes(header)
  -- metadataText runs: [author, " • ", elapsed, " • ", "N votes"]
  local meta = type(header) == "table" and header.metadataText or nil
  if type(meta) ~= "table" or type(meta.runs) ~= "table" then
    return nil, nil
  end
  local author = type(meta.runs[1]) == "table" and Common.safe_text(meta.runs[1].text, 200) or nil
  local votes = nil
  for _, run in ipairs(meta.runs) do
    if type(run) == "table" and type(run.text) == "string" then
      local n = run.text:match("([%d%.,]+)%s*votes?")
      if n then
        votes = tonumber((n:gsub("[^%d]", "")))
      end
    end
  end
  return author, votes
end

--- Shared parser for liveChatPollRenderer as embedded in poll updates and
--- action panels. status: "open" | "closed".
function Polls.from_renderer(renderer, status)
  if type(renderer) ~= "table" then
    return nil
  end
  local header = type(renderer.header) == "table" and
      (renderer.header.liveChatPollHeaderRenderer or renderer.header.pollHeaderRenderer) or nil
  local author, total_votes = metadata_votes(header)
  local question = header and
      (Common.safe_text(Common.simple_text(header.pollQuestion), 300) or
          Common.safe_text(Common.runs_flat(header.pollQuestion), 300)) or nil
  return {
    kind = "poll",
    id = Common.safe_id(renderer.liveChatPollId or renderer.id),
    author = author,
    poll = {
      question = question,
      options = parse_choices(renderer.choices),
      total_votes = total_votes,
      status = status or "open"
    }
  }
end

--- updateLiveChatPollAction -> poll_update event.
function Polls.update(action)
  if type(action) ~= "table" then
    return nil
  end
  local renderer = action.pollToUpdate and
      (action.pollToUpdate.pollRenderer or action.pollToUpdate.liveChatPollRenderer) or nil
  local event = Polls.from_renderer(renderer, "open")
  if event then
    event.kind = "poll_update"
    event.source_action = "updateLiveChatPollAction"
  end
  return event
end

--- showLiveChatActionPanelAction -> poll event (panel contents).
function Polls.from_action_panel(action)
  if type(action) ~= "table" then
    return nil
  end
  local panel = action.panelToShow and action.panelToShow.liveChatActionPanelRenderer or nil
  if not panel or type(panel.contents) ~= "table" then
    return nil
  end
  local renderer = panel.contents.pollRenderer or panel.contents.liveChatPollRenderer
  if not renderer then
    return nil
  end
  local event = Polls.from_renderer(renderer, "open")
  if event then
    event.id = event.id or Common.safe_id(panel.id)
    event.source_action = "showLiveChatActionPanelAction"
  end
  return event
end

--- closeLiveChatActionPanelAction -> poll_closed marker.
function Polls.closed(action)
  if type(action) ~= "table" then
    return nil
  end
  return {
    kind = "poll_closed",
    id = Common.safe_id(action.targetPanelId or action.panelId),
    source_action = "closeLiveChatActionPanelAction"
  }
end

--- Poll results delivered as viewer engagement messages (icon POLL):
--- runs like "option (80%)" … "Poll complete: N votes".
function Polls.from_engagement(renderer)
  local _, flat = Emotes.parse_runs(renderer and renderer.message)
  return {
    kind = "poll_closed",
    id = Common.safe_id(renderer and renderer.id),
    timestamp_usec = Common.timestamp_usec(renderer and renderer.timestampUsec),
    poll = { question = nil, options = {}, status = "closed" },
    text = Common.safe_text(flat) or "",
    source_action = "addChatItemAction"
  }
end

return Polls
