## Purpose

Provide iOS users with mokaGram identity and Desktop capabilities adapted to the platform while preserving accurate privacy and data expectations.

## ADDED Requirements

### Requirement: Product identity and attribution
The app SHALL display the mokaGram name and identity and provide accessible attribution to the Desktop project and its author.

#### Scenario: User views app identity
- **WHEN** the user installs or opens the app and views its settings
- **THEN** the app shows its mokaGram identity and links to the Desktop project's author and source.

### Requirement: Local peer notes
The app SHALL let users create, edit and remove a local note and tag for a peer, isolated by account, without sending them to that peer.

#### Scenario: Edit a local peer note
- **WHEN** a user saves a note for a peer
- **THEN** the note is available after restart for that account and is not sent as a Telegram message.

#### Scenario: Update a peer tag
- **WHEN** a user adds, changes or removes a tag for a peer
- **THEN** the peer's chat-list label updates for the same account and VoiceOver includes the tag when it is present.

### Requirement: Activity privacy
The app SHALL allow users to suppress chat activity announcements per account on this device without suppressing group-call speaking activity.

#### Scenario: Chat activity is hidden
- **WHEN** hiding chat activity is enabled and the user types or records in a chat
- **THEN** the app does not send the corresponding chat activity request.

### Requirement: Story-view privacy
The app SHALL offer an account-specific device-local control to suppress normal and pinned story-view requests, and explain the limits of other sessions and later read acknowledgements.

#### Scenario: Story views are hidden
- **WHEN** the control is enabled before a user views a story on this device
- **THEN** this device does not enqueue a new view acknowledgement for that viewing or send a pinned-story view request.

### Requirement: Automatic chat read control
The app SHALL allow an account to suppress automatic read marks caused by opening chats and discussion threads, with exceptions for selected peers. It SHALL explain that manual actions, notifications, media consumption and other devices can still send receipts.

#### Scenario: Open a non-exempt chat
- **WHEN** automatic read suppression is enabled and a non-exempt chat is viewed
- **THEN** the chat view does not apply an automatic read marker on this device.

#### Scenario: Open an exempt chat
- **WHEN** the account has allowed automatic reading for that chat
- **THEN** the chat view uses its normal automatic read behavior.

### Requirement: Online presence updates
The app SHALL provide an account-specific device-local control that requests offline status and suppresses its periodic online status updates, while explaining that activity and other sessions can reveal presence.

#### Scenario: Online updates are disabled while active
- **WHEN** the user enables this control for the active account
- **THEN** the app requests offline status and does not schedule further online status refreshes for that account while the control remains enabled.

#### Scenario: Online updates are restored
- **WHEN** the user disables this control
- **THEN** the app resumes its normal presence behavior for the current foreground or background state.

### Requirement: Message information
The app SHALL provide the user with available metadata about a selected message, including its identifiers, timestamps, forwarding information and attachment details where present.

#### Scenario: Inspect a message with an attachment
- **WHEN** the user opens message information for a message containing a file
- **THEN** the app shows the available message identifiers, sent time and file metadata without modifying the message.

### Requirement: Account-local text snippets
The app SHALL let users manage account-local snippets and expand known `;name` triggers when sending a supported ordinary chat message, preserving the formatting of text outside replaced triggers.

#### Scenario: Expand a known snippet
- **WHEN** a user sends an ordinary message containing a configured snippet trigger after whitespace
- **THEN** the trigger is replaced with the saved snippet text before the message is sent.

#### Scenario: Unknown snippet
- **WHEN** a message contains a trigger not configured for the current account
- **THEN** that trigger remains unchanged.

### Requirement: Local calculation command
The app SHALL offer an account-specific opt-in `.calc` command that calculates an expression locally and leaves the result in the composer without sending it.

#### Scenario: Calculate an expression
- **WHEN** the user enables the command and submits `.calc 2 + 3 * 4` in an ordinary chat
- **THEN** the composer displays `2 + 3 * 4 = 14` and no message is sent.

#### Scenario: Invalid expression
- **WHEN** an enabled calculation command contains an invalid expression
- **THEN** the app reports an error and leaves the original text in the composer without sending it.

### Requirement: Local snippet and peer-note commands
When quick commands are enabled, the app SHALL handle `.snip` locally for snippet management and `.tag` and `.note` locally for regular private chats, without sending those commands as messages.

#### Scenario: Save a snippet with a command
- **WHEN** the user submits `.snip hello Hello` with quick commands enabled
- **THEN** the account's local `hello` snippet is saved and the command is not sent to the chat.

#### Scenario: Set a private note with a command
- **WHEN** the user submits `.note` followed by text in a regular private chat
- **THEN** the note is stored locally for that account and peer without being sent.

### Requirement: Archive commands and aliases
When quick commands are enabled, the app SHALL allow users to archive or unarchive the current main chat and configure account-local aliases only for supported commands.

#### Scenario: Archive a main chat
- **WHEN** the user submits `.archive` without arguments in an eligible main chat
- **THEN** the app requests the normal Telegram archive operation without sending the command as a message.

#### Scenario: Use an alias
- **WHEN** a user submits an alias assigned to a supported command
- **THEN** the app handles the assigned command using that account's local alias mapping.

### Requirement: Chat notification commands
When quick commands are enabled, the app SHALL handle `.mute` and `.unmute` as chat notification changes and SHALL reject replies instead of treating them as participant moderation commands.

#### Scenario: Temporarily mute a chat
- **WHEN** the user submits `.mute 30m` without replying to a message
- **THEN** the app applies a 30-minute chat notification mute without sending the command.

#### Scenario: Unsupported participant moderation
- **WHEN** the user submits `.mute` in reply to a message
- **THEN** the app explains that participant restrictions are not supported, leaves the command in the composer and does not send it.

### Requirement: Explicit parity and limitations
The app SHALL expose adapted Desktop features with clear scope, data behavior and failure states; incomplete or unsupported features SHALL not be represented as operational.

#### Scenario: Platform prevents an equivalent feature
- **WHEN** an equivalent Desktop feature cannot operate within iOS constraints
- **THEN** the limitation and any supported alternative are documented without pretending the feature was ported.

### Requirement: Central settings and portability
The app SHALL keep mokaGram settings in one registry with typed values and defaults, allow resetting a key, a section or everything, and allow exporting and importing them as a file with a preview of the changes before they are applied.

#### Scenario: Import settings
- **WHEN** the user opens a settings file
- **THEN** the app lists the values that would change and applies none of them until the user confirms.

#### Scenario: Reset a section
- **WHEN** the user resets a section
- **THEN** every key in that section returns to its default and keys in other sections are unchanged.

### Requirement: mokaGram badges
The app SHALL show a mokaGram badge for people on the issued-badge list, obtained without sending messages in any chat, cached on the device, and refreshed periodically and when the app returns to the foreground.

#### Scenario: Badge service unavailable
- **WHEN** the badge list cannot be fetched
- **THEN** the app shows the cached list, shows no error in chats and retries later.

### Requirement: Fake-offer protection
When enabled, the app SHALL mark messages that look like fake Telegram offers with link buttons and SHALL ask for confirmation before opening hidden or suspicious links, except for people the user has exempted.

#### Scenario: Open a suspicious link
- **WHEN** the user taps a link whose visible text differs from its destination in a flagged message
- **THEN** the app shows the real destination and opens it only if the user chooses to continue.

### Requirement: Datacenter ping
The app SHALL let the user measure latency to the Telegram datacenters and SHALL show a per-datacenter result or a failure state.

#### Scenario: Run a ping check
- **WHEN** the user starts the check
- **THEN** the app shows the result for each reachable datacenter and marks unreachable ones as failed.

### Requirement: First-run privacy choices
On first launch the app SHALL ask once whether to hide story views, keep deleted messages and enable scam protection, with every option off until the user turns it on.

#### Scenario: Skip the first-run choices
- **WHEN** the user dismisses the window without choosing
- **THEN** the corresponding features stay off and remain available in settings.

### Requirement: Music across chats
The app SHALL let the user search audio across chats, queue tracks, and see synchronized lyrics where a provider supplies them, with tapping a line seeking to its time.

#### Scenario: Seek from lyrics
- **WHEN** synchronized lyrics are shown and the user taps a line
- **THEN** playback seeks to that line's timestamp.
