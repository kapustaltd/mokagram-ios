## Purpose

Defines the behaviour of the native audio player sheet once mokaGram music (search, recommendations, likes, lyrics) lives inside it instead of on a separate screen.

## ADDED Requirements

### Requirement: No standalone music screen
The mokaGram settings menu SHALL NOT contain a Music entry, and no separate music list screen SHALL exist.

#### Scenario: Settings menu
- **WHEN** the mokaGram settings screen is opened
- **THEN** there is no Music row

### Requirement: Two tabs above the track list
The player sheet SHALL show two tabs above the track list: "From chat" and "Search". Selecting a tab SHALL change the list without closing the sheet or interrupting playback.

#### Scenario: Open from a chat track
- **WHEN** the user taps an audio message in a chat
- **THEN** the sheet opens on "From chat" listing that chat's tracks with the tapped one playing

#### Scenario: Switch tabs while playing
- **WHEN** the user switches to "Search"
- **THEN** the current track keeps playing and the compact player stays visible

### Requirement: Choose the chat for "From chat"
"From chat" SHALL let the user pick which chat's music is listed, defaulting to the chat the track was opened from.

#### Scenario: Pick another chat
- **WHEN** the user picks a different chat
- **THEN** the list shows that chat's tracks and tapping one starts a queue from that chat

### Requirement: Search tab sections
"Search" SHALL contain sections Search, For You and Likes. Search SHALL query the music catalogue by text; For You SHALL show recommendations; Likes SHALL show liked tracks. Tapping a track SHALL play it in a queue made of that section's list.

#### Scenario: Search and play
- **WHEN** the user types a query in Search and taps a result
- **THEN** the track plays and next/previous move through the results

#### Scenario: Like a track
- **WHEN** the user likes a playing track
- **THEN** it appears in Likes and the like state is shown in the player

### Requirement: Cover art always rendered
The sheet rows and the player SHALL show cover art whenever any exists (embedded artwork, catalogue artwork, or the message's thumbnail). A generic placeholder MAY be shown only when no art exists, and SHALL be consistent between rows and player.

#### Scenario: Audio file without embedded art
- **WHEN** a track has no art
- **THEN** a placeholder is shown, and the player does not show a different one

#### Scenario: Catalogue track
- **WHEN** a catalogue track is listed or playing
- **THEN** its artwork is drawn in the row, the compact player and the expanded player

### Requirement: Expanded player layout
Swiping the compact player up or tapping its cover SHALL expand it into a layout with a large cover, a background tinted from the cover, transport controls, progress, and a Lyrics card. Swiping down SHALL collapse it.

#### Scenario: Expand
- **WHEN** the user taps the cover in the compact player
- **THEN** the expanded layout appears and the track list moves out of view

### Requirement: Lyrics card
The Lyrics card SHALL show synced lyrics for the current track with the current line highlighted, scroll with playback, and seek to a line when it is tapped. An expand button SHALL open the lyrics full screen. When no lyrics exist the card SHALL say so.

#### Scenario: Tap a line
- **WHEN** the user taps a lyric line
- **THEN** playback seeks to that line's timestamp

#### Scenario: No lyrics
- **WHEN** no lyrics can be found
- **THEN** the card shows a "no lyrics" state and does not keep loading

### Requirement: Send and add to profile
The sheet SHALL keep the actions to send the current track to a chat and to add it to the profile.

#### Scenario: Add to profile
- **WHEN** the user taps Add to Profile on a catalogue track
- **THEN** the track is added to the profile as it is today
