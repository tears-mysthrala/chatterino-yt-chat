local T = require("tests.test_runner")
local H = require("tests.helpers")
local Actions = require("src.youtube.actions")
local Builder = require("src.messages.builder")

local function event_from(path)
  local action = H.load_fixture(path)
  local events = Actions.from_action(action)
  T.ok(type(events) == "table", path .. " -> events table")
  T.ok(#events >= 1, path .. " -> at least one event")
  return events[1], events
end

-- Every fixture must produce a non-nil event with a kind (nothing is
-- dropped silently), except intentional no-ops.
local FIXTURE_KINDS = {
  ["fixtures/real/addChatItemAction-liveChatTextMessageRenderer.json"] = "text_message",
  ["fixtures/real/addChatItemAction-liveChatViewerEngagementMessageRenderer.json"] = "system",
  ["fixtures/real/addBannerToLiveChatCommand.json"] = "pinned",
  ["fixtures/real/removeChatItemAction.json"] = "deleted_message",
  ["fixtures/synthetic/addChatItemAction-liveChatPaidMessageRenderer.json"] = "super_chat",
  ["fixtures/synthetic/addChatItemAction-liveChatPaidStickerRenderer.json"] = "super_sticker",
  ["fixtures/synthetic/addChatItemAction-liveChatMembershipItemRenderer-new.json"] = "membership",
  ["fixtures/synthetic/addChatItemAction-liveChatMembershipItemRenderer-milestone.json"] = "membership",
  ["fixtures/synthetic/addChatItemAction-liveChatSponsorshipsGiftPurchaseAnnouncementRenderer.json"] = "membership_gift",
  ["fixtures/synthetic/addChatItemAction-liveChatSponsorshipsGiftRedemptionAnnouncementRenderer.json"] = "membership_gift_received",
  ["fixtures/synthetic/addChatItemAction-liveChatModeChangeMessageRenderer.json"] = "mode_change",
  ["fixtures/synthetic/addChatItemAction-liveChatDonationAnnouncementRenderer.json"] = "donation",
  ["fixtures/synthetic/addChatItemAction-liveChatLegacyPaidMessageRenderer.json"] = "legacy_paid",
  ["fixtures/synthetic/addChatItemAction-liveChatPlaceholderItemRenderer.json"] = "placeholder",
  ["fixtures/synthetic/addChatItemAction-liveChatViewerEngagementMessageRenderer-poll.json"] = "poll_closed",
  ["fixtures/synthetic/addLiveChatTickerItemAction-paidMessage.json"] = "ticker_paid",
  ["fixtures/synthetic/addLiveChatTickerItemAction-paidSticker.json"] = "ticker_sticker",
  ["fixtures/synthetic/addLiveChatTickerItemAction-sponsor.json"] = "ticker_member",
  ["fixtures/synthetic/markChatItemAsDeletedAction.json"] = "deleted_message",
  ["fixtures/synthetic/markChatItemsByAuthorAsDeletedAction.json"] = "author_deleted",
  ["fixtures/synthetic/removeChatItemByAuthorAction.json"] = "author_deleted",
  ["fixtures/synthetic/replaceChatItemAction.json"] = "replaced_message",
  ["fixtures/synthetic/removeBannerForLiveChatCommand.json"] = "pin_removed",
  ["fixtures/synthetic/updateLiveChatPollAction.json"] = "poll_update",
  ["fixtures/synthetic/showLiveChatActionPanelAction.json"] = "poll",
  ["fixtures/synthetic/closeLiveChatActionPanelAction.json"] = "poll_closed",
  ["fixtures/synthetic/showLiveChatTooltipCommand.json"] = "system",
  ["fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-badges.json"] = "text_message",
  ["fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-owner-verified.json"] = "text_message",
  ["fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-link.json"] = "text_message",
  ["fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-custom-emoji.json"] = "text_message",
  ["fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-no-message.json"] = "text_message",
  ["fixtures/synthetic/addChatItemAction-unknownRenderer.json"] = "unknown_event",
  ["fixtures/synthetic/unknownAction.json"] = "unknown_event"
}

for path, expected_kind in pairs(FIXTURE_KINDS) do
  local event = event_from(path)
  T.eq(event.kind, expected_kind, path .. " kind")
  -- Every event must be buildable into a Chatterino spec without errors.
  local spec = Builder.to_chatterino_message(event, true)
  T.ok(type(spec) == "table", path .. " builds message spec")
  T.ok(type(spec.message_text) == "string" and #spec.message_text > 0, path .. " has message text")
end

-- Intentional no-op: moderator UI state command must produce zero events.
do
  local events = Actions.from_action(H.load_fixture("fixtures/synthetic/liveChatReportModerationStateCommand.json"))
  T.eq(#events, 0, "moderation state command is a documented no-op")
end

-- Replay actions flatten nested actions.
do
  local events = Actions.from_action(H.load_fixture("fixtures/synthetic/replayChatItemAction.json"))
  T.eq(#events, 1, "replay yields nested events")
  T.eq(events[1].kind, "text_message", "replay nested kind")
end

-- Field-level assertions on representative categories ---------------------

-- Ordinary message: runs, emoji, author, id, timestamp.
do
  local event = event_from("fixtures/real/addChatItemAction-liveChatTextMessageRenderer.json")
  T.ok(event.author ~= nil, "text author")
  T.ok(event.id ~= nil, "text id")
  T.ok(type(event.timestamp_usec) == "number", "text timestamp")
  local has_emoji = false
  for _, run in ipairs(event.runs or {}) do
    if run.type == "emoji" then
      has_emoji = true
      T.eq(run.emoji, "😘", "unicode emoji preserved")
    end
  end
  T.ok(has_emoji, "emoji run present")
  T.ok(event.text:find("😘", 1, true) ~= nil, "flat text keeps emoji")
end

-- Badges: moderator + member roles.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-badges.json")
  T.ok(event.roles.moderator, "moderator role")
  T.ok(event.roles.member, "member role")
  T.eq(event.badges[2].months, 24, "member months parsed")
  local spec = Builder.to_chatterino_message(event, false)
  local flat = spec.message_text
  T.ok(flat:find("Moderator speaking", 1, true) ~= nil, "badge message text")
end

-- Owner + verified.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-owner-verified.json")
  T.ok(event.roles.owner, "owner role")
  T.ok(event.roles.verified, "verified role")
end

-- Links: redirect unwrapped, internal links prefixed.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-link.json")
  local links = {}
  for _, run in ipairs(event.runs) do
    if run.type == "link" then
      links[#links + 1] = run.url
    end
  end
  T.eq(#links, 2, "two link runs")
  T.eq(links[1], "https://example.com", "redirect unwrapped")
  T.eq(links[2], "https://www.youtube.com/watch?v=FAKEVID123", "internal link prefixed")
end

-- Custom channel emoji: emote run with name + image URL.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatTextMessageRenderer-custom-emoji.json")
  local emote = nil
  for _, run in ipairs(event.runs) do
    if run.type == "emote" then
      emote = run
    end
  end
  T.ok(emote ~= nil, "custom emote run")
  T.eq(emote.name, ":wave:", "custom emote shortcut")
  T.ok(emote.url ~= nil, "custom emote url")
  T.ok(emote.custom, "custom flag")
end

-- Super Chat: amount verbatim, colors, message runs.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatPaidMessageRenderer.json")
  T.eq(event.amount, "€5.00", "amount verbatim")
  T.eq(event.colors.header_background, "#ffca28", "ARGB color converted")
  T.eq(event.text, "Great stream! 🎉", "superchat text with emoji")
  local spec = Builder.to_chatterino_message(event, false)
  T.ok(spec.message_text:find("Super Chat", 1, true) ~= nil, "superchat label")
  T.ok(spec.message_text:find("€5.00", 1, true) ~= nil, "superchat amount in text")
end

-- Super Sticker: sticker alt, amount, fallback author from photo label.
do
  local event = event_from("fixtures/synthetic/addChatItemAction-liveChatPaidStickerRenderer.json")
  T.eq(event.amount, "$2.00", "sticker amount")
  T.eq(event.sticker.alt, "Thanks!", "sticker alt text")
  T.ok(event.sticker.url ~= nil, "sticker url")
  local spec = Builder.to_chatterino_message(event, false)
  T.ok(spec.message_text:find("Super Sticker", 1, true) ~= nil, "sticker label")
end

-- Membership new vs milestone.
do
  local new_event = event_from("fixtures/synthetic/addChatItemAction-liveChatMembershipItemRenderer-new.json")
  T.eq(new_event.membership_kind, "new", "new member kind")
  T.eq(new_event.level, "Gold", "level from welcome runs")
  local milestone = event_from("fixtures/synthetic/addChatItemAction-liveChatMembershipItemRenderer-milestone.json")
  T.eq(milestone.membership_kind, "milestone", "milestone kind")
  T.eq(milestone.member_since, " for 12 months", "tenure text")
  T.eq(milestone.level, "Gold", "milestone level")
  T.ok(milestone.text:find("Still here", 1, true) ~= nil, "milestone message")
end

-- Gifts.
do
  local gift = event_from("fixtures/synthetic/addChatItemAction-liveChatSponsorshipsGiftPurchaseAnnouncementRenderer.json")
  T.eq(gift.gift_count, 5, "gift count")
  T.eq(gift.author, "Generous Gifter", "gift author from header")
  local received = event_from("fixtures/synthetic/addChatItemAction-liveChatSponsorshipsGiftRedemptionAnnouncementRenderer.json")
  T.ok(received.text:find("gifted a membership", 1, true) ~= nil, "redemption text")
end

-- Moderation: deletion, author deletion, replace.
do
  local deleted = event_from("fixtures/synthetic/markChatItemAsDeletedAction.json")
  T.eq(deleted.target_message_id, "FAKE-TARGET-ID-1", "deletion target id")
  T.ok(deleted.system_text:find("deleted", 1, true) ~= nil, "deletion state text")
  local by_author = event_from("fixtures/synthetic/markChatItemsByAuthorAsDeletedAction.json")
  T.eq(by_author.target_author_channel_id, "UCFAKECHANNEL0000000002", "author deletion channel")
  local replaced = event_from("fixtures/synthetic/replaceChatItemAction.json")
  T.eq(replaced.target_message_id, "FAKE-PH-1", "replace target")
  T.eq(replaced.replacement.kind, "text_message", "replacement event embedded")
  T.ok(replaced.replacement.text:find("real message", 1, true) ~= nil, "replacement text")
end

-- Pinned banner: dedupe-safe id, embedded content.
do
  local pinned = event_from("fixtures/real/addBannerToLiveChatCommand.json")
  T.ok(pinned.id:match("^pin%-") ~= nil, "pinned id prefixed")
  T.eq(pinned.target_message_id, "FAKE-TARGET-ID-1", "pinned target")
  T.ok(pinned.pinned_message ~= nil, "pinned content embedded")
  T.ok(pinned.header_text:find("Pinned by", 1, true) ~= nil, "pinned header")
end

-- Polls: update carries full state.
do
  local update = event_from("fixtures/synthetic/updateLiveChatPollAction.json")
  T.eq(update.poll.question, "Best option?", "poll question")
  T.eq(#update.poll.options, 2, "poll options")
  T.eq(update.poll.total_votes, 23, "poll vote count")
  T.ok(update.poll.options[1].ratio > 0.7, "poll ratio")
  local panel = event_from("fixtures/synthetic/showLiveChatActionPanelAction.json")
  T.eq(panel.poll.question, "Best option?", "panel poll question")
  local closed = event_from("fixtures/synthetic/closeLiveChatActionPanelAction.json")
  T.eq(closed.id, "FAKE-PANEL-1", "close panel id")
  local results = event_from("fixtures/synthetic/addChatItemAction-liveChatViewerEngagementMessageRenderer-poll.json")
  T.ok(results.text:find("Poll complete", 1, true) ~= nil, "poll results text")
end

-- Mode change.
do
  local mode = event_from("fixtures/synthetic/addChatItemAction-liveChatModeChangeMessageRenderer.json")
  T.eq(mode.mode.name, "slow", "slow mode detected")
  T.eq(mode.mode.enabled, true, "mode enabled")
end

-- Tickers.
do
  local paid = event_from("fixtures/synthetic/addLiveChatTickerItemAction-paidMessage.json")
  T.eq(paid.amount, "€5.00", "ticker amount")
  T.eq(paid.ticker.duration_sec, 30, "ticker duration")
  T.ok(paid.detail ~= nil, "ticker detail message")
  local sticker = event_from("fixtures/synthetic/addLiveChatTickerItemAction-paidSticker.json")
  T.eq(sticker.sticker.alt, "Party sticker", "ticker sticker pack")
  local member = event_from("fixtures/synthetic/addLiveChatTickerItemAction-sponsor.json")
  T.eq(member.ticker.detail_text, "12", "ticker member months")
end

-- Unknown renderer/action: visible fallback, sensitive data redacted in samples.
do
  local unknown = event_from("fixtures/synthetic/unknownAction.json")
  T.eq(unknown.kind, "unknown_event", "unknown action fallback")
  T.ok(unknown.system_text:find("someFutureAction", 1, true) ~= nil, "unknown action named")
  local unknown_renderer = event_from("fixtures/synthetic/addChatItemAction-unknownRenderer.json")
  T.ok(unknown_renderer.system_text:find("liveChatFutureRenderer2042", 1, true) ~= nil, "unknown renderer named")
  T.ok(unknown_renderer.system_text:find("content from a renderer", 1, true) ~= nil, "unknown text extracted")
end

-- Builder: system events are system specs; chat events carry YT prefix.
do
  local deleted = event_from("fixtures/synthetic/markChatItemAsDeletedAction.json")
  local spec = Builder.to_chatterino_message(deleted, false)
  T.ok(spec.system, "deletion spec is system")
  local text = event_from("fixtures/real/addChatItemAction-liveChatTextMessageRenderer.json")
  local chat_spec = Builder.to_chatterino_message(text, true)
  T.ok(not chat_spec.system, "chat spec not system")
  T.eq(chat_spec.elements[1].text, "YT", "YT prefix element")
  T.ok(chat_spec.id:match("^yt%-chat%-") ~= nil, "message id prefixed")
end
