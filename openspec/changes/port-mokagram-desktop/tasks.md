## 1. Inventory and build

- [ ] 1.1 Inventory all Desktop `mokagram` modules, integrations marked `Mokagram:`, resources, settings, commands and patches against the exact Desktop revision; classify every user-visible feature.
- [ ] 1.2 Establish the pinned Xcode/Bazel build and test environment; build and run on iPhone and iPad.
- [ ] 1.3 Verify app name, launcher icon, alternate icons, launch/onboarding identity and in-app attribution on supported versions. Name fixed to "mokaGram" everywhere user-visible (`Telegram/BUILD`, all InfoPlist locales, UI titles); "Telegram" app-name uses in the bundled English strings and InfoPlist usage texts rewritten (service names such as Premium, Stars, Passport, Ads, Business kept); attribution rows exist in Settings. Pending: alternate icons (need source art), launch/onboarding screens, server-delivered non-English language packs (need a runtime rewrite like Desktop `BrandRewrite`), device verification.
- [ ] 1.4 Preserve notices and document iOS changes, privacy, data storage and platform limitations.

## 2. Local notes and profile

- [ ] 2.1 Verify existing local notes/tag editing, account isolation, persistence, deletion and accessible UI on device; address limitations.
- [ ] 2.2 Port Desktop tag presentation in chat list and peer information, and note editing/length behavior. Chat-list label and live refresh implemented; accessibility and device verification pending.
- [ ] 2.3 Port message information: IDs, dates, forwards, attachments, media details and available voice metadata. Basic details and cached Opus header metadata implemented; device validation and remaining fields pending.
- [ ] 2.4 Port optional registration-date lookup with destination disclosure, caching and failure handling.
- [ ] 2.5 Inventory and adapt profile/verification badge features and attribution. Badge list and levels are tracked in 8.2.

## 3. Privacy and safety

- [ ] 3.1 Verify chat activity suppression on network, including encrypted chats, threads, toggle transitions and group calls; cover account isolation and other devices.
- [ ] 3.2 Port ghost controls for read receipts including threads, content receipts, per-chat exceptions and explicit mark-as-read. Automatic chat-opening reads and profile exceptions implemented; media and device/network tests remain.
- [ ] 3.3 Port online suppression and explicit offline transition with accurate server/session limitations. Presence manager control implemented; network, lifecycle and device verification pending.
- [ ] 3.4 Port story-view suppression and verify server interactions. Ordinary and pinned view paths now have account-scoped controls; request-level and device tests remain.
- [ ] 3.5 Port ghost schedules and per-control settings, including overnight schedules. Schedule model (overnight windows, per-account storage) and schedule-aware privacy getters implemented and host-tested (8 tests); settings UI, boundary timer that re-evaluates online presence, and device verification pending.
- [ ] 3.6 Port hiding blocked senders in groups and related history filters.
- [ ] 3.7 Port streamer mode masking for phone, usernames, links, IDs, names, notifications and copy behavior. Progress: masking rules (phone, username, link, ID, name), copy modes and the `streamer.*` settings are ported with host tests (`MokoStreamer`, 8 tests); Wired (unbuilt) into the Settings screen phone and username rows in `PeerInfoSettingsItems.swift`; profile header, invite links, usernames list, notification extension, copy actions and device verification pending.
- [ ] 3.8 Port scam warnings and guard protections for strangers, threats, stickers and mass-add events.

## 4. History and messages

- [ ] 4.1 Design and implement local deleted-message retention and display, privacy controls, quotas and deletion.
- [ ] 4.2 Port edited-message history and filters with retention limits.
- [ ] 4.3 Assess TTL/ephemeral content and bot handling and implement explicitly documented supported behavior.
- [ ] 4.4 Port quote creation, message info and reporting additions.
- [ ] 4.5 Port selection limits, edited indicators and other Desktop chat integration changes.
- [ ] 4.6 Port snippets with formatting preservation, management and account-scoped storage. Plain-text snippets and expansion in ordinary messages implemented; rich snippet formatting, rich-message support and device validation pending.
- [ ] 4.7 Port quick commands and aliases with permissions, confirmation and error handling. Opt-in .calc, .id, .archive/.unarchive, chat-notification .mute/.unmute, .save, plain-text .snip, private-chat .tag/.note and aliases implemented; participant moderation, other commands and device verification remain.

## 5. Media and integrations

- [ ] 5.1 Port music library, player and track forwarding behavior.
- [ ] 5.2 Port SoundCloud integration with source, authentication and failure handling.
- [ ] 5.3 Port lyrics and optional visual effects with provider behavior and caching.
- [ ] 5.4 Port Saveinator integration, explicitly handling network and service failures.
- [ ] 5.5 Port Stars statistics and relevant message/account utilities.

## 6. Appearance and performance

- [ ] 6.1 Port bubble, avatar shape, color, typography and player appearance settings with accessible iOS defaults.
- [ ] 6.2 Port deletion effects and controls with reduced-motion support.
- [ ] 6.3 Adapt Desktop anti-lag/performance options to supported iOS resource and lifecycle behavior.
- [ ] 6.4 Inventory and adapt remaining UI, localization and quality-of-life changes.

## 7. Plugins, updates and release

- [ ] 7.1 Inventory plugin API, Python host, installation, permissions, store, update and command hooks; evaluate feasible iOS runtime and distribution constraints.
- [ ] 7.2 Implement supported plugin functionality with explicit permissions, isolation and user-visible failure states, or document concrete platform incompatibilities.
- [ ] 7.3 Adapt Desktop update/distribution flows to the actual iOS installation method.
- [ ] 7.4 Run unit, integration and device tests for every feature; verify localization, accessibility, security boundaries and data lifecycle.
- [ ] 7.5 Reconcile all Desktop integration points against the inventory, document any intentional differences, and complete release build verification.

## 8. Additional Desktop capabilities (found in the 2026-10-27 re-audit of Desktop `bb203b658d`)

These modules or recent commits had no task above. Each one is a user-visible Desktop feature; Desktop references are under `Telegram/SourceFiles/mokagram/`.

- [ ] 8.1 Port the central settings registry and the "Customization" screen (`settings/`): typed keys, per-key / per-section / full reset, "changed from default" markers, export and import of a `.mokaset` JSON file with a dry-run preview of what will change. Storage must be account-scoped where the setting is, and only differences from defaults are written.
- [ ] 8.2 Port mokaGram badges (`Badges`, commits `106caaa67d`…`b9068b31ba`, `732c9b00b6`): the issued-badge list obtained from the badge bot by inline query without sending messages, disk cache, periodic and on-foreground refresh, retry on missing session, per-user look and caption for levels 2 and 3, team/support variants. Extends 2.5; define how a badge renders next to the iOS verification and emoji-status marks.
- [ ] 8.3 Port Guard (`scam/`, `Guard`): fake-offer detection for messages with link buttons, warning banner on the message, interception of hidden-link / mini-app / escrow-bot links with "open anyway", and the per-person threat exemption list. Extends 3.8.
- [ ] 8.4 Port the DC ping check (`misc/mokagram_ping`, `.ping`) as a screen and as a quick command.
- [ ] 8.5 Port miscellany from `misc/`: account-count limit setting (`misc.max_accounts`), sticker from photo, probable pack-owner lookup (explicitly a heuristic), "copy with author" (`[date time] author: text`), and brand rewriting of "Telegram" strings where it is legal and accurate. Progress: copy-with-author formatter and the sticker-set owner heuristic are in `MokoMisc` with host tests; `misc.max_accounts` is intentionally not ported (see inventory); A "Copy with author" message context-menu action is added in `ChatInterfaceStateContextMenus.swift` (not built or device-verified); sticker from photo and brand rewriting pending.
- [ ] 8.6 Port localization behavior (`lang/`): Russian text as the key, English fallback for languages without a translation, system language enabled automatically on first launch. Decide how this maps to iOS `PresentationStrings`.
- [ ] 8.7 Port the first-run window (commit `151b7e1e20`): one-time choice of hiding story views, keeping deleted messages and scam protection. All choices default to off until the user opts in.
- [ ] 8.8 Port the delete-messages and send-files dialog additions (`BoxParts`: ~10 and ~16 Desktop markers) as native iOS action sheets, with pill-style actions and accessible labels.
- [ ] 8.9 Port music extras beyond 5.1: music search across chats, player queue, synchronized lyrics with tap-a-line-to-seek and manual scroll that pauses auto-scroll for 3 s, artist name in the mini-player, forwarding tracks.
- [ ] 8.10 Port the report dialog additions (`ui/mokagram_report_box`) alongside 4.4.
- [ ] 8.11 Port small chat UI changes: sent-message font setting, slash-command menu styling, poll and checklist layout (`510b97c3dc`, `3a26e0899b`), pill tabs for emoji/stickers/GIFs, hex colour picker with `#RRGGBB` hint, GIF and sticker autoplay settings, settings search.
- [ ] 8.12 Port the power-saving integration (`perf/`): background economy and "toaster" mode, tied to iOS Low Power Mode and app lifecycle. Folds into 6.3.
- [x] 8.13 Document every Desktop feature that has no iOS equivalent in `inventory.md` with its reason, so it is not mistaken for an unported gap (see "Not applicable on iOS" there).
