# User GUI smoke validation - 2026-08-08

## Environment

- Chatterino 2.5.5 on Windows.
- Published plugin version: 1.0.0.
- Real YouTube live stream and named Chatterino split.

## Observed

- `/yt-chat <url>` registered and accepted.
- Plugin reported successful connection to the active live chat.
- Ordinary messages were delivered with channel name, moderator badge, author
  and message text.
- Connection remained active without an observed failure during the user's
  current session.

## Evidence boundary

The user supplied a screenshot showing the connected split and live messages.
No user-identifiable screenshot is committed to the repository. This is a smoke
validation, not evidence of a multi-hour soak.

## Pending

- At least two hours on a busy stream while observing memory growth, duplicate
  messages, reconnect behavior and timer stability.
- GUI validation of the v1.1.0 presentation delay and new operational commands.
