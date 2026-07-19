# Compatibility Matrix — YouTube Live Chat actions & renderers

Status keys (per GOAL.md):

- `Full`: all semantically relevant information is represented.
- `Degraded by Chatterino API`: all information is preserved, but a
  demonstrated visual limitation of Chatterino applies.
- `Unsupported`: not allowed for mandatory 1.0.0 chat events.

Minimum Chatterino version: **2.5.x** (tested against v2.5.5 API surface).
The plugin message-element API in 2.5.x supports text/timestamp/mention/
linebreak elements only — no remote images, no clickable link elements.
Everything image-based (emotes, stickers, avatars, badge icons) is
therefore represented textually; standard Unicode emoji render natively.
Message mutation (`find_message_by_id` + `replace_message`) **is**
available in 2.5.x and is used for deletions and replacements.

Sources for the inventory: `xenova/chat-downloader` (`sites/youtube.py`),
`sigvt/masterchat` (`src/chat/actions/*`), `LuanRT/YouTube.js`,
`taizan-hokuto/pytchat`, plus anonymized real captures from
`get_live_chat` taken 2026-07-19 (`fixtures/real/`).

## Actions

| Action | Renderer(s) carried | Handler | Chatterino output | Fixture | Status | Notes |
|---|---|---|---|---|---|---|
| `addChatItemAction` | all item renderers below | `Actions.from_action` → `Renderers.from_item` | per renderer | `fixtures/real/`, `fixtures/synthetic/` | Full | — |
| `addLiveChatTickerItemAction` | `liveChatTickerPaidMessageItemRenderer` | `System.ticker_paid` | compact ticker line + full detail | `addLiveChatTickerItemAction-paidMessage.json` | Degraded by Chatterino API | ticker bar visuals become a text line |
| `addLiveChatTickerItemAction` | `liveChatTickerPaidStickerItemRenderer` | `System.ticker_sticker` | compact ticker line + sticker alt | `addLiveChatTickerItemAction-paidSticker.json` | Degraded by Chatterino API | — |
| `addLiveChatTickerItemAction` | `liveChatTickerSponsorItemRenderer` | `System.ticker_member` | compact ticker line + months/gift | `addLiveChatTickerItemAction-sponsor.json` | Degraded by Chatterino API | — |
| `replaceChatItemAction` | any item renderer | `Moderation.replaced` | in-place replace via `replace_message`; new message if target unknown | `replaceChatItemAction.json` | Full | delivers placeholder resolutions |
| `markChatItemAsDeletedAction` | n/a (`targetItemId`, `deletedStateMessage`) | `Moderation.deleted` | in-place 🗑 marker on the original message | `markChatItemAsDeletedAction.json` + `fixtures/real/removeChatItemAction.json` shape | Full | falls back to system event with id |
| `markChatItemsByAuthorAsDeletedAction` | n/a (`externalChannelId`) | `Moderation.author_deleted` | system event with channel id | `markChatItemsByAuthorAsDeletedAction.json` | Full | — |
| `removeChatItemByAuthorAction` | n/a | `Moderation.author_deleted` | system event | `removeChatItemByAuthorAction.json` | Full | — |
| `removeChatItemAction` | n/a (`targetItemId`) | `Moderation.removed` | in-place removal marker / system event | `fixtures/real/removeChatItemAction.json` | Full | captured in the wild |
| `addBannerToLiveChatCommand` | `liveChatBannerRenderer` | `System.pinned` | 📌 event with header + pinned message content | `fixtures/real/addBannerToLiveChatCommand.json` | Degraded by Chatterino API | banner chrome becomes text; id `pin-<target>` avoids duplicates |
| `removeBannerForLiveChatCommand` | n/a (`targetActionId`) | `System.pin_removed` | unpin system event | `removeBannerForLiveChatCommand.json` | Full | — |
| `updateLiveChatPollAction` | `pollRenderer` (embedded) | `Polls.update` | poll with question, options, ratios, total votes | `updateLiveChatPollAction.json` | Degraded by Chatterino API | bars become text; updates throttled 1/10 s per poll |
| `showLiveChatActionPanelAction` | `liveChatActionPanelRenderer` → `pollRenderer` | `Polls.from_action_panel` | initial poll display | `showLiveChatActionPanelAction.json` | Degraded by Chatterino API | — |
| `closeLiveChatActionPanelAction` | n/a | `Polls.closed` | poll-closed marker | `closeLiveChatActionPanelAction.json` | Full | — |
| `showLiveChatTooltipCommand` | `tooltipRenderer` | `System.tooltip` | system event with notice text | `showLiveChatTooltipCommand.json` | Full | — |
| `replayChatItemAction` | nested actions | `Actions.from_action` (recursive) | replayed events (read-only viewer treats like live) | `replayChatItemAction.json` | Full | offset time not displayed (live viewer scope) |
| `liveChatReportModerationStateCommand` | n/a | documented no-op | none (not a chat-visible event; moderator UI state) | `liveChatReportModerationStateCommand.json` | Full | intentionally ignored; logged at debug level |
| unknown action | — | `Fallback.unknown` | visible ⚠ event with exact name + extracted text | `unknownAction.json` | Full | rate-limited log; redacted debug sample |

## Item renderers

| Renderer | Handler | Chatterino output | Fixture | Status | Notes |
|---|---|---|---|---|---|
| `liveChatTextMessageRenderer` | `Text.from_text_renderer` | author (role-tagged, colored) + runs | real + 6 synthetic variants | Full | mixed runs, links unwrapped, unknown runs marked `[?]`, Unicode emoji native |
| `liveChatPaidMessageRenderer` | `Monetary.super_chat` | `[Super Chat · amount] author: text` + highlight color | `addChatItemAction-liveChatPaidMessageRenderer.json` | Degraded by Chatterino API | tier colors → `highlight_color`; amount verbatim, no conversion |
| `liveChatPaidStickerRenderer` | `Monetary.super_sticker` | `[Super Sticker · amount] author: sticker “alt”` | `addChatItemAction-liveChatPaidStickerRenderer.json` | Degraded by Chatterino API | sticker image → alt text; author from photo label when name absent |
| `liveChatMembershipItemRenderer` | `Memberships.from_renderer` | `[New member · level]` / `[Member · tenure] author: text` | new + milestone fixtures | Full | level, tenure, member message preserved |
| `liveChatSponsorshipsGiftPurchaseAnnouncementRenderer` | `Memberships.gift_purchase` | `[Gift ×N] author …` | gift purchase fixture | Full | count parsed from header runs |
| `liveChatSponsorshipsGiftRedemptionAnnouncementRenderer` | `Memberships.gift_redemption` | `[Gift received] text` | gift redemption fixture | Full | — |
| `liveChatViewerEngagementMessageRenderer` | `System.viewer_engagement` / `Polls.from_engagement` | system event (mode notices) or 📊 poll results | real + poll-results fixtures | Full | icon `POLL` switches to poll-results display |
| `liveChatModeChangeMessageRenderer` | `System.mode_change` | ⚙ slow/members/subscribers on/off + description | mode-change fixture | Full | — |
| `liveChatPlaceholderItemRenderer` | polling coalescer | `✨ N reactions` per 10 s window | placeholder fixture | Degraded by Chatterino API | reaction spam coalesced; replacements delivered (ADR-005) |
| `liveChatDonationAnnouncementRenderer` | `Monetary.donation` | `[Donation · amount] author: text` | donation fixture | Full | — |
| `liveChatLegacyPaidMessageRenderer` | `Monetary.legacy_paid` | `[Member · amount] author: header/text` | legacy fixture | Degraded by Chatterino API | rare legacy shape |
| `liveChatPurchasedProductMessageRenderer` | `Fallback.unknown` | ⚠ event with extracted fields | — | Degraded by Chatterino API | unconfirmed in current sources; generic fallback preserves event |
| `liveChatModerationMessageRenderer` / `liveChatAutoModMessageRenderer` | `Fallback.unknown` | ⚠ event with extracted fields | — | Degraded by Chatterino API | unconfirmed in current sources; generic fallback preserves event |
| unknown renderer | `Fallback.unknown` | ⚠ visible event, never dropped | `addChatItemAction-unknownRenderer.json` | Full | — |

## Continuations

| Continuation type | Parser | Status | Notes |
|---|---|---|---|
| `invalidationContinuationData` | `Continuations.pick` | Full | preferred; real `timeoutMs=10000` captured |
| `timedContinuationData` | `Continuations.pick` | Full | — |
| `liveChatReplayContinuationData` | `Continuations.pick` | Full | replay scope |
| `reloadContinuationData` | `Continuations.pick` | Full | — |
| `seekContinuationData` | `Continuations.pick` | Full | defensive |

Clamps: min 500 ms, max 15 000 ms, fallback 1 000 ms + jitter (settings:
`chat_poll_min_ms`, `chat_poll_max_ms`, `chat_poll_fallback_ms`).

## Event categories without a dedicated chat renderer (current sources)

| GOAL.md category | Situation | How 1.0.0 covers it |
|---|---|---|
| Live redirect / raid | No dedicated renderer exists in current open implementations or captures | Stream end (continuation stops) → system event; new target detected by offline monitor |
| Q&A / questions | No current chat renderer found | Would surface via `unknown_event` fallback without being lost |
| Celebration effects | No current chat renderer found | Would surface via `unknown_event` fallback |
| Chat disabled / stream end | Absence of `continuationContents` / HTTP 403 / missing continuation | `Polling.stop` + system event + return to offline watch |
| Slow mode / members-only / subscribers-only | `liveChatModeChangeMessageRenderer` + engagement messages | Full (see matrix) |

## Current known visual limitations (Chatterino 2.5.x plugin API)

1. Remote images (custom emotes, stickers, avatars, badge icons) render as
   text: emote shortcuts, sticker alt text, badge tags `[MOD|MEMBER·12m]`.
   Chatterino `master` adds `c2.Image`; when a stable release ships it, the
   builder can upgrade these elements without protocol changes.
2. Link runs render as link-colored text (no clickable link element in
   2.5.x); the URL is preserved in the element tooltip and message text.
3. Super Chat tier colors apply to the message highlight, not a full
   banner background.
4. Poll bars/percentages render as structured text.
5. Ticker items render as compact lines; their full underlying event is
   preserved and displayed.
