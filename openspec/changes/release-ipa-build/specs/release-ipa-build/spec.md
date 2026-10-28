## Purpose

Defines what building and checking a release IPA of the iOS client means, so "release build done" has one meaning.

## ADDED Requirements

### Requirement: Release IPA is produced
A release build for arm64 devices SHALL complete with `-c opt` and produce `Telegram.ipa` with dSYM files, from a clean checkout of the target branch.

#### Scenario: Clean build succeeds
- **WHEN** the release build is run on the target branch
- **THEN** it finishes without errors and `bazel-bin/Telegram/Telegram.ipa` exists

### Requirement: Artifact is identifiable
The IPA SHALL be named by its signing kind, have a SHA-256 file next to it, and carry the requested build number.

#### Scenario: Build number
- **WHEN** a build number is passed
- **THEN** the IPA's `CFBundleVersion` equals it

### Requirement: Signing is stated honestly
The result SHALL state whether the IPA is signed (ad-hoc with a real profile) or unsigned (placeholder), and an unsigned IPA SHALL NOT be presented as installable.

#### Scenario: No signing secrets
- **WHEN** signing secrets are absent
- **THEN** the artifact is named unsigned and reported as not installable on a device

### Requirement: Release IPA is smoke-tested
A signed release IPA SHALL be installed on a registered device and launch, sign in, open a chat and play a track before it is called done.

#### Scenario: Smoke test
- **WHEN** the signed IPA is installed
- **THEN** the app launches without a crash and the checks above pass

### Requirement: Bundle identifier
The release IPA SHALL use the bundle identifier `app.starfruit2689.orange1525` for the main app, and the identifiers of its extensions SHALL be derived from it, so that the app group, keychain access group and notification service extension match the identifier the IPA is installed with.

#### Scenario: Identifier in the IPA
- **WHEN** the built IPA's main `Info.plist` is read
- **THEN** `CFBundleIdentifier` is `app.starfruit2689.orange1525`

#### Scenario: Extensions follow the app
- **WHEN** the IPA's extensions are inspected
- **THEN** each extension's identifier starts with `app.starfruit2689.orange1525.`
