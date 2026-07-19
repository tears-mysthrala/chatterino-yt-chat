# Compatibility Matrix (Innertube actions/renderers)

Status keys:

- `Full`
- `Degraded by Chatterino API`
- `Unsupported` (not allowed for mandatory 1.0.0 chat events)

| Action | Renderer | Handler | Chatterino output | Fixture | Status | Notes |
|---|---|---|---|---|---|---|
| addChatItemAction | liveChatTextMessageRenderer | `src/youtube/actions.lua` + `src/youtube/renderers.lua` | Regular message | `fixtures/actions/addChatItemAction-liveChatTextMessageRenderer.json` | Full | Runs aggregated, unknown runs preserved as markers |
| addChatItemAction | liveChatPaidMessageRenderer | same | Super Chat text event | `fixtures/actions/addChatItemAction-liveChatPaidMessageRenderer.json` | Degraded by Chatterino API | Color tiers kept semantically if visual API is limited |
| addChatItemAction | liveChatPaidStickerRenderer | same | Super Sticker event | (covered by unit path) | Degraded by Chatterino API | Sticker image may degrade to text |
| addChatItemAction | liveChatMembershipItemRenderer | same | Membership event | (covered by unit path) | Full | Includes header/text when present |
| addChatItemAction | liveChatPlaceholderItemRenderer | same | Placeholder event | (covered by unit path) | Full | Placeholder represented explicitly |
| addChatItemAction | liveChatPollRenderer | same | Poll event | (covered by unit path) | Degraded by Chatterino API | Poll bars/graphics degrade to text |
| addLiveChatTickerItemAction | any supported item renderer | `handlers.addLiveChatTickerItemAction` | Ticker-derived event | (shared fixtures) | Degraded by Chatterino API | Ticker visuals are textualized |
| replaceChatItemAction | any supported replacement renderer | `handlers.replaceChatItemAction` | Replacement event | (shared fixtures) | Full | Uses replacement item payload |
| markChatItemAsDeletedAction | n/a | `handlers.markChatItemAsDeletedAction` | Moderation deletion marker | (unit action coverage) | Full | Message id included when available |
| markChatItemsByAuthorAsDeletedAction | n/a | `handlers.markChatItemsByAuthorAsDeletedAction` | Author hide marker | (unit action coverage) | Full | External channel id preserved |
| removeChatItemAction | n/a | `handlers.removeChatItemAction` | Removal system event | (unit action coverage) | Full | Target item id emitted |
| addBannerToLiveChatCommand | liveChatBannerRenderer contents | `handlers.addBannerToLiveChatCommand` | Pinned/banner event | (unit path) | Degraded by Chatterino API | Banner layout degrades to text |
| removeBannerForLiveChatCommand | n/a | `handlers.removeBannerForLiveChatCommand` | Pin removed event | (unit path) | Full | Explicit unpin marker |
| updateLiveChatPollAction | n/a | `handlers.updateLiveChatPollAction` | Poll update marker | (unit path) | Full | Poll id retained when present |
| replayChatItemAction | nested action item | `handlers.replayChatItemAction` | Replay-translated event | (unit path) | Full | Reuses add item parsing |
| unknown action | unknown renderer | fallback | Safe unknown event | `tests/unit/actions_renderers_spec.lua` | Full | Rate-limited logs, visible event |

## Continuations

| Continuation type | Parser | Status |
|---|---|---|
| timedContinuationData | `src/youtube/continuations.lua` | Full |
| invalidationContinuationData | same | Full |
| liveChatReplayContinuationData | same | Full |
| reloadContinuationData | same | Full |

## Current known visual limitations

1. Native YouTube sticker animation is represented semantically rather than animated.
2. Poll visual bars are rendered as structured text.
3. Some badge/image details depend on Chatterino plugin element capabilities.
