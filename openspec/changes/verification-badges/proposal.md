## Why

Desktop mokaGram shows a custom verification badge for its developers and for "subs" (users who were issued the badge). iOS draws only Telegram's stock verified icon, so the product identity is missing on the platform where most users are.

## What Changes

- Add personal verification icons for `@ecronx` and `@xdshkaaa`.
- Add one shared mokaGram verification icon for every other holder of the badge ("subs").
- Fetch the list of badge holders the way Desktop does (`Mokagram::Badges` in `mokagram_misc.cpp`: `badges.json` mirrors plus inline queries `badges:N` to `@mokagent`), cache it on device, refresh in the background.
- Draw the custom icon everywhere iOS draws the verified icon: chat list, chat header, profile header, message author/forward headers, contacts and search rows, story list, notifications.

## Capabilities

### New Capabilities

- `verification-badges`: which users get which mokaGram verification icon, where it is shown, and how the holder list is obtained and cached.

### Modified Capabilities

None.

## Impact

`TelegramPresentationData` (`PresentationResourcesChatList` verified icon), `ChatTitleComponent`, `PeerInfoHeaderNode`, `ContactsPeerItem`, `ChatMessageNotificationItem`, `StoryPeerListItemComponent`, `CallListCallItem` and the other ~38 files that read `isVerified`; a new holder-list store in `submodules/Moko/MokoCore`; icon assets; a network call to the badge list endpoints.
