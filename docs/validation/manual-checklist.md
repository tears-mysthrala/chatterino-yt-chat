# Manual validation checklist

- [ ] Offline channel added via `/yt-chat https://www.youtube.com/@handle/live`
- [ ] Channel transitions offline -> live and chat starts automatically
- [ ] Regular text messages shown correctly
- [ ] Unicode emoji shown correctly
- [ ] YouTube emoji/custom emoji represented correctly (or degraded with semantics)
- [ ] Super Chat represented with amount/currency text
- [ ] Super Sticker represented (visual or semantic fallback)
- [ ] Membership events represented
- [ ] Pinned/banner messages represented
- [ ] Moderation deletions represented
- [ ] Poll update represented
- [ ] End-of-stream/reconnect behavior verified
- [ ] Multiple splits receive same stream without duplicate polling
- [ ] Restart Chatterino preserves configured channels
- [ ] State recovery works with `.bak` after synthetic corruption
