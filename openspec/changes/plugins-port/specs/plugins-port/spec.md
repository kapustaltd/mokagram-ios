## Purpose

mokaGram plugin system on iOS. The gate requirement below is final. All DRAFT requirements depend on user answers to the open questions in design.md and are not approved.

## ADDED Requirements

### Requirement: Plugin system scope is defined before implementation
No plugin implementation work SHALL start until the open questions in this change's design are answered and this spec is rewritten with concrete requirements.

#### Scenario: Apply is requested
- **WHEN** someone asks to implement this change before the open questions are answered
- **THEN** the work stops and the open questions are raised first

## DRAFT Requirements (NOT FINAL, recommendation only, assume the recommended options of design.md)

### Requirement: DRAFT Plugin runtime is lazy and switchable
The app SHALL start the plugin runtime only when at least one plugin is enabled, SHALL provide a global off switch, and SHALL start without loading any plugin when the previous launch crashed during plugin load (safe mode).

#### Scenario: No plugins enabled
- **WHEN** the app launches and no plugin is enabled
- **THEN** the interpreter is not initialised

#### Scenario: Crash during plugin load
- **WHEN** the previous launch ended during plugin loading
- **THEN** plugins are not loaded and the user is told why, with a way to re-enable

### Requirement: DRAFT Desktop plugin file compatibility
A `.plugin` file with metadata (`__id__`, `__version__`, `__min_version__`, `__permissions__`, `__icon__`, `__dependencies__`, `__details__`) that works on Desktop SHALL load on iOS, and `platform` SHALL be `ios` for plugins that ask.

#### Scenario: Showcase plugin
- **WHEN** `examples/showcase.plugin` is installed on iOS
- **THEN** it loads, its command runs, and calls with no iOS equivalent return a documented unsupported result instead of crashing the plugin

### Requirement: DRAFT Install requires explicit consent
Installing a plugin SHALL show its name, author, version, requested and statically detected permissions, and SHALL record the grants bound to the SHA-256 of the file. A changed file SHALL need re-approval. Permissions in the never-granted set (`raw_api`, `native`, `files.any`, `network.any`, `subprocess`) SHALL NOT be granted.

#### Scenario: Plugin file changes
- **WHEN** an installed plugin file's hash differs from the approved one
- **THEN** the plugin does not run until the user approves again

#### Scenario: Call without permission
- **WHEN** a plugin calls an SDK function it was not granted
- **THEN** the call returns `None` and an audit record is written

### Requirement: DRAFT Signed store
The store SHALL accept a catalog only if its Ed25519 signature over `"mokagram-plugins\n" + index` verifies with the pinned key, and SHALL install a plugin only if its SHA-256 and size match the signed entry and the file name matches the safe pattern.

#### Scenario: Bad signature
- **WHEN** the signature does not verify
- **THEN** no entry is shown or installed

#### Scenario: Hash mismatch
- **WHEN** a downloaded file's hash differs from the entry
- **THEN** the install is rejected and the user is told

### Requirement: DRAFT Limits and audit
The host SHALL enforce per-plugin rate limits (300 actions per minute total, 60 TL calls, 30 http requests), hook timeouts (5 s), http response size (20 MB), file paths limited to the plugin data and temp folders, and SHALL write every plugin action to a rotating audit log.

#### Scenario: Hook hangs
- **WHEN** an event callback runs longer than 5 s
- **THEN** it is abandoned, logged and the app UI is not blocked

### Requirement: DRAFT Privacy policy applies to plugins
Plugin actions that send, read-mark, or signal typing SHALL pass through the same Ghost and Guard policy as user actions, and message access SHALL be scoped to an explicit account.

#### Scenario: Ghost mode on
- **WHEN** a plugin calls `mark_read` while Ghost mode blocks read receipts
- **THEN** no read receipt is sent

### Requirement: DRAFT Plugin management UI
Settings SHALL contain a Plugins section with the list, enable/disable, per-plugin settings, install from file or link, store, update, log view and global switch. Plugin menu points SHALL appear in the existing message, chat, profile and attach menus.

#### Scenario: Open plugin settings
- **WHEN** the user opens a plugin with `create_settings`
- **THEN** its fields render and persist

### Requirement: DRAFT Distribution flag
The plugin host SHALL be removable at build time so a variant without it can be produced.

#### Scenario: Build without host
- **WHEN** the flag disables plugins
- **THEN** the app builds and no interpreter, store UI or install UI is present
