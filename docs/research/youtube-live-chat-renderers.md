# Research notes: YouTube Live Chat actions/renderers

This project maps commonly observed Innertube action/renderers used by YouTube Live Chat:

- `addChatItemAction`
- `addLiveChatTickerItemAction`
- `replaceChatItemAction`
- `markChatItemAsDeletedAction`
- `markChatItemsByAuthorAsDeletedAction`
- `removeChatItemAction`
- `addBannerToLiveChatCommand`
- `removeBannerForLiveChatCommand`
- `updateLiveChatPollAction`
- `replayChatItemAction`

Renderers covered in baseline parser:

- `liveChatTextMessageRenderer`
- `liveChatPaidMessageRenderer`
- `liveChatPaidStickerRenderer`
- `liveChatMembershipItemRenderer`
- `liveChatPlaceholderItemRenderer`
- `liveChatPollRenderer`

Unknown actions/renderers are surfaced through explicit fallback events.
