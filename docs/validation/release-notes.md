# chatterino-yt-chat 1.5.0

Adds broadcast-session metadata for viewing streaks in the multichat overlay.

## Highlights

- The overlay receives the active YouTube video ID as the stream identity.
- Streaks use the stable YouTube channel identity instead of display names or
  the viewer's local arrival date.
- Existing initial-history suppression and live-message delivery remain
  covered by the automated suite.

## Assets

- `chatterino-yt-chat-1.5.0.zip`
- `chatterino-yt-chat-1.5.0.zip.sha256`

Verify the ZIP against the `.sha256` asset from this release, preserve the
plugin's `data/` directory while updating, and restart Chatterino.

## Validation

- Automated suite: 1,394 assertions, 0 failures.
- Fixtures: 40 checked, 0 failures.
- Integration coverage verifies that the active video and channel identities
  are included in overlay events.
