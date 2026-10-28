## Purpose

Defines the send-time offer to turn a link into downloaded media through Saveinator, matching Desktop mokaGram behaviour.

## ADDED Requirements

### Requirement: Offer only for a lone supported link
When the user sends a message whose entire text (after trimming) is a single link to a supported service, and the feature is enabled, the client SHALL ask whether to download it via Saveinator or send it as text. It SHALL NOT ask for messages with other text, several words, an unsupported host, or an empty field.

#### Scenario: Lone supported link
- **WHEN** the user sends `https://youtu.be/xyz` and nothing else
- **THEN** a choice is shown: download via Saveinator, or send as text

#### Scenario: Link with other text
- **WHEN** the text contains a link and other words
- **THEN** the message is sent as usual with no offer

#### Scenario: Unsupported host
- **WHEN** the lone link points to a host that is not supported
- **THEN** the message is sent as usual with no offer

### Requirement: Supported services
Supported hosts SHALL be those Desktop supports: YouTube, TikTok, X/Twitter, Instagram, Reddit, Pinterest, Spotify, SoundCloud, VK, Twitch and Yandex Music (including subdomains and short-link domains).

#### Scenario: Subdomain
- **WHEN** the link host is `m.youtube.com`
- **THEN** it counts as supported

### Requirement: Send as text keeps the original behaviour
Choosing to send as text SHALL send the original message unchanged, with the same send options.

#### Scenario: Send as text
- **WHEN** the user picks "send as text"
- **THEN** the link is sent as an ordinary text message

### Requirement: Download and send
Choosing to download SHALL let the user pick what to download and the maximum video quality where relevant, clear the input field, show progress, and send the downloaded media to the same chat with the reply, silent, schedule and thread options that were active when the user pressed send. On failure the user SHALL see an error and the original text SHALL NOT be lost.

#### Scenario: Successful download
- **WHEN** the download completes
- **THEN** the media is sent to the chat as a message

#### Scenario: Failure
- **WHEN** the download fails
- **THEN** an error is shown and the link text is restored to the input field

### Requirement: Setting
The offer SHALL be controlled by a mokaGram setting that is enabled by default, as on Desktop.

#### Scenario: Disabled
- **WHEN** the setting is off
- **THEN** links are sent as ordinary text with no offer
