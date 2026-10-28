## 1. Remove the standalone screen

- [x] 1.1 Remove the Music row from the mokaGram settings and `MokoMusicSettings.register()` push; keep settings that other code still uses
- [x] 1.2 Port the list rows and state logic of `MokoMusicController` into reusable pieces, then delete the controller

## 2. Tabs and sources

- [x] 2.1 Add the "From chat" / "Search" tab control to `OverlayAudioPlayerControllerNode`
- [x] 2.2 From chat: add the chat picker and rebuild the queue from the picked chat
- [x] 2.3 Search: search field, Search / For You / Likes sections, loading/empty/offline/error states
- [x] 2.4 Tap in any section starts a `MokoMusicPlaylistLocation` queue from that section's list

## 3. Cover art

- [x] 3.1 Add the single cover resolver (embedded, catalogue, message thumb, placeholder)
- [x] 3.2 Use it in sheet rows, compact player, `MediaPlaybackHeaderPanelComponent` and the expanded player (header panel draws no cover by spec; rows gated to catalogue tracks)

## 4. Expanded player and lyrics

- [x] 4.1 Expanded layout: large cover, tinted background, controls, progress; swipe-up / cover-tap to expand and swipe-down to collapse
- [x] 4.2 Lyrics card with current-line highlight, tap-to-seek, no-lyrics state
- [x] 4.3 Expand-to-fullscreen button reusing the existing lyrics view
- [x] 4.4 Keep send-to-chat and add-to-profile actions reachable

## 5. Verification

- [ ] 5.1 Build `debug_sim_arm64` and drive the sim: open a chat track, switch tabs, search, play, like, expand, tap a lyric line
- [ ] 5.2 Confirm plain Telegram audio (non-moko) playback and the sheet look are unchanged
- [x] 5.3 Update `MokoMusicUI` tests if any cover the removed controller
