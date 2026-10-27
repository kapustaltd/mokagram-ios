## Why

iOS currently uses Telegram's upstream interface and only a small part of the Desktop mokaGram feature set. Users need the same product identity and as much of the Desktop functionality as iOS can support.

## What Changes

- Inventory Desktop-specific modules and integration points and port each user-visible capability to iOS.
- Add account-scoped settings, privacy controls, local data, chat tools, media, safety and appearance features.
- Preserve source attribution, distinguish platform-specific limitations, and verify behavior on device before calling a feature complete.

## Capabilities

### New Capabilities

- `desktop-parity`: mokaGram identity and adapted Desktop features for the iOS client.

### Modified Capabilities

None.

## Impact

TelegramCore, Postbox, TelegramUI, app assets, network integrations, device storage, build configuration and tests. Third-party services, plugin execution, background work and distribution must be assessed individually for iOS compatibility.
