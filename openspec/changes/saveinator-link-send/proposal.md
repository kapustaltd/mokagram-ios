## Why

On Desktop, sending a message that is just a link to a supported service (YouTube, TikTok, Instagram, ...) offers to download the media through Saveinator and send the file instead of the link. iOS has no Saveinator at all, so users paste links and get a bare preview.

## What Changes

- When the user sends a message whose whole text is one link to a supported service, show a choice: download via Saveinator and send the media, or send as text.
- Choice of what to download (everything / video only / ...; max video height), as in Desktop's `Choice { media, maxHeight }`.
- Download through the Saveinator API, then send the result as media to the same chat, honouring the send options already chosen (reply, silent, scheduled, thread).
- A setting to enable/disable the offer (Desktop key `saveinator.enabled`).
- Confirmed by the user and implemented (4.2): a "Download via Saveinator" action in the message context menu for messages that contain a supported link.

## Capabilities

### New Capabilities

- `saveinator-link-send`: when the send-time offer appears, what the user can choose, and how the result is sent.

### Modified Capabilities

None.

## Impact

Chat input send path in `TelegramUI` (a hook before a text message is sent), a new Saveinator client in `submodules/Moko`, settings registry entry, string table, network permission to the Saveinator API host. Desktop reference: `Telegram/SourceFiles/mokagram/saveinator/mokagram_saveinator.cpp` (`OfferSendDownload`, `SupportedHost`, `Normalized`, `Download`).
