# Manual validation checklist (pre-release)

Environment: Chatterino **2.5.x** (see `chatterino-install.md` for the
automated/offscreen part). Tick each item with date + evidence. Do not
publish user-identifiable content without anonymizing it.

## Lifecycle

- [ ] Offline channel added: `/yt-chat https://www.youtube.com/@handle/live`
      reports offline registration.
- [ ] That channel starts a stream → chat connects automatically
      (offline monitor).
- [ ] Restart Chatterino → configured channels restored from
      `data/YT_CHAT.json`.
- [ ] Corrupt `YT_CHAT.json` manually → plugin recovers from `.bak` and
      logs a warning.
- [ ] Upgrade test: install previous version state, install new ZIP,
      verify migration + channels intact.

## Chat content

- [ ] Ordinary messages (author, text, multi-run).
- [ ] Unicode emoji visible natively.
- [ ] Custom channel emotes shown as `:shortcut:` text.
- [ ] Links shown (link-colored text with URL preserved).
- [ ] Badges: `[MOD]`, `[OWNER]`, `[✓]`, `[MEMBER·Nm]` prefixes.
- [ ] Super Chat: `[Super Chat · amount] author: text` + highlight.
- [ ] Super Sticker: `[Super Sticker · amount] author: sticker “alt”`
      (fixtures acceptable if generating payments is unreasonable).
- [ ] Memberships: new member, milestone (tenure + level + message).
- [ ] Gift memberships: purchase (×N) and reception.
- [ ] Pinned message: banner event, dedupe against the original message,
      unpin event.
- [ ] Moderation: deleted message replaced in place (or 🗑 system event),
      user-hidden event.
- [ ] Poll: open, updates (throttled), results/closed.
- [ ] Mode changes: slow mode / members-only / subscribers-only.
- [ ] Placeholders/reactions coalesced (`✨ N reactions`).
- [ ] End of stream: system event + channel returns to offline watch.

## Robustness

- [ ] Reconnect: disable/enable network mid-stream → backoff retry
      (max 30 s), resumes without duplicates.
- [ ] Unknown renderer/action (or debug-injected fixture): visible ⚠
      event, no crash, chat keeps flowing.
- [ ] Multiple splits of the same stream: identical content, single
      polling loop (check log `chat_started` once).
- [ ] Multiple channels concurrently.
- [ ] Long soak: ≥ 2 h on a busy chat; watch for memory growth and
      duplicate messages.

## Privacy spot-checks

- [ ] Logs contain no API keys, continuations or full payloads.
- [ ] `YT_CHAT.json` contains only channels/splits/settings/schema.
- [ ] Debug mode off by default.
