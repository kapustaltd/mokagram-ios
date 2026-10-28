## Why

The mokaGram music feature lives on its own screen (mokaGram → Music) with its own list UI, which looks foreign next to Telegram's native player and is a second place to start playback. Users already open the native player sheet by tapping a track; that is where music search, recommendations and likes belong. The sheet also shows no cover art for ordinary audio files and its lyrics view is a separate screen.

## What Changes

- **BREAKING**: remove the standalone music screen (`mokoMusicController`) and its entry in the mokaGram settings menu.
- Add two tabs above the track list of the native player sheet (`OverlayAudioPlayerController`): **From chat** and **Search**.
  - From chat: the current track list, plus a chat picker to choose which chat's music is listed.
  - Search: sub-sections **Search**, **For You**, **Likes**, backed by the existing SoundCloud client, recommender and library.
- Always draw cover art in the sheet and compact player (embedded artwork, SoundCloud artwork, or a generated placeholder, never the bare note glyph when art exists).
- Expand the compact player (swipe up or tap the cover) into a Spotify-like layout: large cover, background tinted from the cover, transport controls, a Lyrics card with an expand-to-fullscreen button. Synced lyrics with tap-to-seek are reused.
- Keep send-to-chat / add-to-profile actions available from the sheet.

## Capabilities

### New Capabilities

- `music-player-sheet`: tabs, sources, cover art, expanded layout and lyrics behaviour of the native player sheet for mokaGram music.

### Modified Capabilities

None.

## Impact

`submodules/TelegramUI/Sources/OverlayAudioPlayerControllerNode.swift` (1748 lines) and `OverlayAudioPlayerControlsNode.swift`, `MediaPlaybackHeaderPanelComponent`, `submodules/Moko/MokoMusicUI` (controller removed, logic reused), `MokoMusicSettings.register()` and the mokaGram settings row that pushes the music screen, `MokoMusicPlaylistLocation` in `AccountContext`, string table entries.
