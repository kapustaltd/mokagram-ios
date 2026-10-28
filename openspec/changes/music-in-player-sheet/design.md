## Context

Observed in the repo:
- The standalone screen is `mokoMusicController(context:initialQuery:)` (`MokoMusicController.swift`, an ItemList screen), pushed from `MokoMusicSettings.register()`.
- The sheet is `OverlayAudioPlayerController` / `OverlayAudioPlayerControllerNode` and `OverlayAudioPlayerControlsNode`. The node already special-cases `MokoMusicPlaylistLocation` (lines ~140 and ~515); catalogue tracks use `Namespaces.Message.Local` ids.
- The compact bar is `MediaPlaybackHeaderPanelComponent`, also aware of `MokoMusicPlaylistLocation`.
- Lyrics: `mokoLyricsController(context:)` is pushed from `OverlayAudioPlayerControlsNode` (line ~1225), a separate screen; synced lyrics with tap-to-seek exist (`MokoLyrics.swift`, commit a5775c3cfa).
- Data/logic modules (`MokoMusic`: SoundCloud client, queue, library, recommender, downloader) are UI-free and stay.
- Reference screenshots (user): `Screenshot 2026-10-28 at 10.45.55.heic` (current sheet), `…10.54.37.heic` (Spotify layout).

## Goals / Non-Goals

**Goals:**
- Everything music-related reachable from the native sheet, with native look.
- Spotify-style expanded player and lyrics card.

**Non-Goals:**
- Changing the music backend, queue model or download/cache logic.
- Plugin-provided music sources (plugins are a separate change, `plugins-port`).
- Changing audio session or playback engine.

## Decisions

- **Tabs are added to the sheet node, not a new controller.** A segmented control above the list drives which data source feeds the existing list; the chat source keeps the current `SharedMediaPlaylist` path, the Search source builds a `MokoMusicPlaylistLocation`.
- **Search tab owns a search field and a sub-section switch** (Search / For You / Likes) reusing `MokoMusicLibrary`, `MokoRecommender`, and the SoundCloud client; UI code from `MokoMusicController` is ported into list items of the sheet and then the controller is deleted.
- **Expanded layout is a state of the controls node**, driven by a vertical pan on the compact player and a tap on the cover, interruptible; the track list is hidden in that state. (Assumption from "ага" to the expand-by-swipe-or-tap option; the user did not specify the gesture precisely.)
- **Cover art through one resolver** returning the best available image for a row/player (embedded → catalogue → message thumb → placeholder), used by rows, compact player and expanded player so they cannot disagree.
- **Background tint** sampled once from the cover at low resolution and cached per track; transition animated.
- **Lyrics card** is hosted in the expanded layout; the full-screen button reuses the existing lyrics screen content.

## Risks / Trade-offs

- `OverlayAudioPlayerControllerNode` is large and shared with non-moko playback; every change must leave plain Telegram playback untouched (gate on playlist kind where needed).
- Hit-testing and gestures: a vertical pan on the compact player competes with the sheet's own dismiss pan; needs explicit gesture priority.
- A pair of raw members is a pair a backend can half-implement (CLAUDE.md note); keep the tab source as one object, not a pair of closures.
- Search needs network; empty/offline/error states must be designed per section.
