local Polls = {}

local function get_text(node)
  if type(node) ~= "table" then
    return nil
  end
  return node.simpleText or node.text
end

function Polls.from_renderer(renderer)
  local poll = {
    kind = "poll",
    poll_id = renderer.pollId or renderer.id,
    question = get_text(renderer.title),
    options = {}
  }
  if type(renderer.choices) == "table" then
    for _, choice in ipairs(renderer.choices) do
      table.insert(poll.options, {
        label = get_text(choice.text),
        votes = get_text(choice.voteRatioIfSelected) or get_text(choice.votePercentageIfSelected)
      })
    end
  end
  return poll
end

return Polls
