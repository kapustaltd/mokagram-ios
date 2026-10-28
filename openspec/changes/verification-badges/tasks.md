## 1. Source data and assets

- [x] 1.1 Read `Mokagram::Badges` in Desktop `mokagram_misc.cpp` and record the endpoints, JSON shape, `@mokagent` query format and the user ids of the two developers
- [ ] 1.2 Obtain the shared icon and both personal icons from Desktop/the user and add them as iOS assets (light/dark where needed)

## 2. Holder list

- [x] 2.1 Implement the fetcher (https mirror, GitHub raw, `@mokagent` paged fallback) in MokoCore (https GitHub raw + @mokagent badges:N fallback; the http IP mirror is disabled because of ATS)
- [x] 2.2 Implement the on-device cache, launch-time load and throttled background refresh
- [x] 2.3 Implement `MokoBadges.kind(for:)` and the launch-time registration used by non-Moko modules
- [x] 2.4 Unit tests: parsing, malformed data keeps cache, developer ids win over list entries

## 3. Drawing

- [x] 3.1 Extend the verified-icon factory in `PresentationResourcesChatList` to return the icon for a badge kind (done as `Peer.mokaBadgeIconFileId` / `verificationIconFileId` returning the badge custom emoji, not a static-image factory)
- [x] 3.2 Switch icon-drawing call sites to it: `ChatTitleComponent`, `PeerInfoHeaderNode`, `ContactsPeerItem`, chat list item, message headers, `ChatMessageNotificationItem`, `StoryPeerListItemComponent`, `CallListCallItem` (CallListCallItem and the Telegram-notification title icon draw static images and keep the official icon; unchecked on device)
- [x] 3.3 Make rows relayout when the badge kind changes (descriptor/equality) (ChatListItemNode and ContactsPeerItemNode relayout on `mokaBadgesChangedNotificationName`; other surfaces pick the badge up on their next update)

## 4. Verification

- [ ] 4.1 Build `debug_sim_arm64` and check chat list, header, profile, group message and notification for a developer, a sub and a non-holder
  Manual: build; open a chat list with @ecronx, a holder from badges.json and a plain user; check chat title, profile header, a group message from each, contacts, story strip; a holder with the Telegram verified flag must show exactly one (mokaGram) icon. Not yet compiled or run.
- [ ] 4.2 Check offline launch uses the cache
  Manual: launch once online, enable airplane mode, force-quit and relaunch; badges must still show from the cache.
