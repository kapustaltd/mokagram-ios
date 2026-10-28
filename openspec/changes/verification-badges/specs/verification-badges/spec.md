## Purpose

Defines which users show a mokaGram verification icon in the iOS client, which icon each one gets, and how the list of holders is obtained, so the iOS client matches Desktop mokaGram.

## ADDED Requirements

### Requirement: Personal icons for the developers
The client SHALL show a personal verification icon for `@ecronx` and a personal verification icon for `@xdshkaaa`, each different from the shared icon and from each other.

#### Scenario: Developer appears in a chat list
- **WHEN** a chat with `@ecronx` or `@xdshkaaa` is in the chat list
- **THEN** the row shows that user's personal icon next to the name

### Requirement: Shared icon for subs
The client SHALL show the shared mokaGram icon for every user on the badge holder list who is not one of the two developers.

#### Scenario: Holder in a group message
- **WHEN** a message from a holder is shown in a group
- **THEN** the author header shows the shared mokaGram icon

#### Scenario: Not a holder
- **WHEN** a user is neither on the list nor one of the developers
- **THEN** the client shows no mokaGram icon (Telegram's own verified icon, if any, is unchanged)

### Requirement: Icon shown on every verification surface
The custom icon SHALL be drawn wherever the client draws a verified icon for a user: chat list, chat header, profile, message headers, contacts and search results, story list and in-app notifications.

#### Scenario: Profile
- **WHEN** a holder's profile is opened
- **THEN** the profile header shows the same icon as the chat list does

### Requirement: Holder list source and caching
The client SHALL load the holder list from the same sources as Desktop, keep the last good copy on device, show badges from that copy on launch without waiting for the network, and refresh it in the background. A failed refresh SHALL NOT remove badges that were already known.

#### Scenario: Offline launch
- **WHEN** the app starts without network and a cached list exists
- **THEN** badges from the cached list are shown

#### Scenario: Refresh fails
- **WHEN** every source fails or returns malformed data
- **THEN** the cached list stays in use and no error is shown to the user

### Requirement: Telegram's own verification wins
A user that Telegram itself marks as verified SHALL keep Telegram's verified icon unless the user is a developer or holder, in which case the mokaGram icon replaces it.

#### Scenario: Holder who is also Telegram-verified
- **WHEN** a holder also has Telegram's verified flag
- **THEN** exactly one icon, the mokaGram one, is drawn
