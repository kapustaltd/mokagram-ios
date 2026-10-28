## Why

A release (`-c opt`, `release_arm64`) IPA is needed as the deliverable of the work above. The repo already has a CI workflow (`.github/workflows/build.yml`, manual dispatch) that builds one, but a release build has not been confirmed end to end with the current tree (Rust MTProto engine, Moko modules, FFmpeg 8, SQLCipher 4.19), and the local command in `CLAUDE.md` only covers `debug_sim_arm64`.

## What Changes

- Produce a release IPA for arm64 devices from the current branch and verify it.
- Document the local release build command next to the debug one.
- Fix whatever breaks only in release (`-O` builds, dSYM generation, Rust crates built at opt-level 3, no `-Clto` rule).
- Confirm what the IPA is signed with and that it installs on a registered device.

## Capabilities

### New Capabilities

- `release-ipa-build`: what a release IPA build must produce and how it is verified.

### Modified Capabilities

None.

## Impact

`build-system/Make/Make.py` (`release_arm64` configuration), `.github/workflows/build.yml`, `build-system/mokagram/prepare.py`, `CLAUDE.md`/`README.md` build sections. No product code unless the release build exposes a defect.
