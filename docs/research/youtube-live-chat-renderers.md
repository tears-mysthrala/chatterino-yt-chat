# Research notes: YouTube Live Chat actions/renderers (verified 2026-07-19)

Sources inspected directly:

- `xenova/chat-downloader` — `chat_downloader/sites/youtube.py`
  (`_KNOWN_*_ACTION_TYPES` tables, `_REMAPPING` field map).
- `sigvt/masterchat` — `src/chat/actions/*.ts` (polls, tickers, banners,
  gifts, memberships, mode changes).
- `LuanRT/YouTube.js` — live chat parser classes.
- `taizan-hokuto/pytchat` — `processors/default/renderer/*`.
- Real anonymized captures: `GET @LofiGirl/live` + `get_live_chat` polls
  (2026-07-19), see `fixtures/real/` and VAL-009 in TRACKER.md.

## Actions observed in current implementations

| Action | Payload | Notes |
| --- | --- | --- |
| `addChatItemAction` | `item.{<renderer>}` | main carrier |
| `addLiveChatTickerItemAction` | `item.{ticker renderer}`, `durationSec` | ticker bar entries |
| `replaceChatItemAction` | `targetItemId`, `replacementItem` | placeholder resolution / edits |
| `markChatItemAsDeletedAction` | `targetItemId`, `deletedStateMessage.runs` | single deletion |
| `markChatItemsByAuthorAsDeletedAction` | `externalChannelId` (+ state message) | purge by author |
| `removeChatItemByAuthorAction` | `externalChannelId` | hide user (captured live) |
| `removeChatItemAction` | `targetItemId` | captured live (9× in one poll) |
| `addBannerToLiveChatCommand` | `bannerRenderer.liveChatBannerRenderer` | pinned message banner (captured live) |
| `removeBannerForLiveChatCommand` | `targetActionId` | unpin |
| `updateLiveChatPollAction` | `pollToUpdate.pollRenderer` | full poll state each update |
| `showLiveChatActionPanelAction` | `panelToShow.liveChatActionPanelRenderer.contents.pollRenderer` | initial poll |
| `closeLiveChatActionPanelAction` | `targetPanelId` | poll closed |
| `showLiveChatTooltipCommand` | `tooltip.tooltipRenderer.detailsText` | notices |
| `replayChatItemAction` | `actions[]`, `videoOffsetTimeMsec` | replay batches |
| `liveChatReportModerationStateCommand` | — | moderator UI state, not chat-visible → documented no-op |

## Renderers and key fields

- `liveChatTextMessageRenderer`: `id`, `authorName.simpleText`,
  `authorExternalChannelId`, `authorPhoto.thumbnails[]`,
  `authorBadges[].liveChatAuthorBadgeRenderer`
  (`icon.iconType`: `OWNER|MODERATOR|VERIFIED`, or
  `customThumbnail` + `tooltip` "Member (N months)"), `message.runs[]`
  (`text`, `text`+`navigationEndpoint.commandMetadata.webCommandMetadata.url`,
  `emoji`{`emojiId`, `shortcuts[]`, `searchTerms[]`, `image.thumbnails[]`,
  `isCustomEmoji`}), `timestampUsec`. `message` can rarely be an empty object.
- `liveChatPaidMessageRenderer`: + `purchaseAmountText.simpleText`,
  `headerBackgroundColor`, `headerTextColor`, `bodyBackgroundColor`,
  `bodyTextColor`, `authorNameTextColor`, `timestampColor` (ARGB ints).
- `liveChatPaidStickerRenderer`: `sticker.thumbnails[]` +
  `sticker.accessibility.accessibilityData.label`, `purchaseAmountText`,
  `backgroundColor`, `moneyChipTextColor`, `moneyChipBackgroundColor`;
  `authorName` may be absent (use `authorPhoto` accessibility label).
- `liveChatMembershipItemRenderer`: new member → no `message`/`empty`,
  `headerSubtext.runs` = "Welcome <level>!" or "New Member"; milestone →
  `headerPrimaryText.runs[1..]` = tenure, `headerSubtext` = level,
  `message.runs` optional.
- `liveChatSponsorshipsGiftPurchaseAnnouncementRenderer`:
  `header.liveChatSponsorshipsHeaderRenderer`{`authorName`, `authorPhoto`,
  `authorBadges`, `primaryText.runs` [prefix, count, middle, channel],
  `image.thumbnails`}.
- `liveChatSponsorshipsGiftRedemptionAnnouncementRenderer`: `message.runs`
  ("X was gifted a membership by Y").
- `liveChatViewerEngagementMessageRenderer`: `icon.iconType`
  (`YOUTUBE_ROUND` = system notice, `POLL` = poll results), `message.runs`
  or `simpleText`, optional `actionButton`. Captured live:
  "Subscribers-only mode …".
- `liveChatModeChangeMessageRenderer`: `text` ("Slow mode is on" /
  "Members-only mode …" / "subscribers-only …"), `subtext`.
- `liveChatPlaceholderItemRenderer`: `id`, `timestampUsec` (reaction spam /
  optimistic placeholders).
- `liveChatDonationAnnouncementRenderer`: `donationAmountText`,
  `subtext.runs`.
- `liveChatLegacyPaidMessageRenderer`: `purchaseAmountText`,
  `headerBackgroundColor`, `headerSubtext`, `message`.
- Tickers: `liveChatTickerPaidMessageItemRenderer`{`amount.simpleText`,
  `fullDurationSec`, `amountTextColor`, `startBackgroundColor`,
  `endBackgroundColor`, `showItemEndpoint.showLiveChatItemEndpoint.renderer
  .liveChatPaidMessageRenderer`}; `liveChatTickerPaidStickerItemRenderer`
  {`tickerThumbnails[0]`(thumbnails+accessibility), endpoint→sticker};
  `liveChatTickerSponsorItemRenderer`{`detailText` (months or runs),
  `detailIcon` (`GIFT`?), `sponsorPhoto`, endpoint→membership/gift renderer}.
- `liveChatBannerRenderer`: `header.liveChatBannerHeaderRenderer`
  (`icon.iconType=KEEP`, `text.runs` "Pinned by X"), `contents.{message
  renderer}`, `targetId`, `actionId`, `bannerType`.
- Polls: `pollRenderer`/`liveChatPollRenderer`:
  `header.pollHeaderRenderer`{`pollQuestion.simpleText`,
  `metadataText.runs` [author, " • ", elapsed, " • ", "N votes"],
  `thumbnail`, `liveChatPollType`}, `liveChatPollId`,
  `choices[]`{`text.runs`, `voteRatio` (0–1)}.
- Unconfirmed/rare (fallback-covered): `liveChatPurchasedProductMessageRenderer`,
  `liveChatModerationMessageRenderer`, `liveChatAutoModMessageRenderer`.

## Continuations

`continuationContents.liveChatContinuation.continuations[]` nodes:
`invalidationContinuationData` (preferred; `timeoutMs` honored — 10000 ms
captured live), `timedContinuationData`, `liveChatReplayContinuationData`,
`reloadContinuationData`, `seekContinuationData` (defensive). Missing
`continuationContents` = stream ended / chat disabled (observed: offline
channels serve no `liveChatRenderer` at all).

## Categories with no current dedicated renderer

- Raids/redirects: no chat renderer in any audited source. Stream end +
  offline redetection covers the operational event.
- Q&A: no current renderer found (fallback covers it if YouTube adds one).
- Celebration effects: no current renderer found (fallback covers).
