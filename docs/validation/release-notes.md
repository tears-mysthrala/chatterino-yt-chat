# chatterino-yt-chat 1.4.1

Safety update for joining very large YouTube live chats.

## Highlights

- The initial history load keeps only the newest 50 normalized events.
- Initial delivery is split into chunks of 10 so Chatterino's UI thread is not
  flooded by a single large response.
- Live messages after the initial response remain complete and continue at
  YouTube's requested polling cadence.
- Overlay publication remains enabled for every delivered event.

## Assets

- `chatterino-yt-chat-1.4.1.zip`
- `chatterino-yt-chat-1.4.1.zip.sha256`

Verify the ZIP against the `.sha256` asset from this release, preserve the
plugin's `data/` directory while updating, and restart Chatterino.

## Validation

- Automated suite: 1,393 assertions, 0 failures.
- Fixtures: 40 checked, 0 failures.
- The load scenario verifies a 120-event initial response is reduced to 50 and
  begins with a 10-event delivery chunk.
