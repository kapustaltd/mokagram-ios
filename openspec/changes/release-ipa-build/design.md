## Context

- `Make.py` already defines `release_arm64`: `-c opt`, `--ios_multi_cpus=arm64`, `--apple_generate_dsym`, `--output_groups=+dsyms`, plus `common_release_args`.
- `.github/workflows/build.yml` (`workflow_dispatch`, `macos-26`) prepares config and signing via `build-system/mokagram/prepare.py`, imports the `.p12`, builds `release_arm64` with `--buildNumber=${{ github.run_number }}` and uploads `Mokagram-adhoc.ipa` or `Mokagram-unsigned.ipa` plus SHA-256.
- `CLAUDE.md` documents only the debug simulator command, which uses a different configuration file and codesigning repo.
- Release-only hazards from CLAUDE.md: Rust crates must keep `-Copt-level=3` annotations and no `-Clto`; per-module `-O` differences; Swift 6.4 miscompile pattern (`[weak]` capture with a mutable local) shows up at `-Onone` and `-O`.

## Goals / Non-Goals

**Goals:**
- A reproducible release IPA path, locally and in CI, with a stated signing kind and a device smoke test.

**Non-Goals:**
- App Store/TestFlight submission, distribution profiles and the watch app (`--embedWatchApp`) are not included.
- Changing product behaviour.

## Decisions

- **Reuse the existing CI workflow** instead of a second pipeline; add only what is missing (docs, verification steps).
- **Local command** is the CI command with a local configuration path, documented once in `CLAUDE.md`.
- **Order**: build the release IPA after the other four changes land, from the branch that contains them (so it contains what is being delivered). This is my assumption about intent; the user only asked for the task.

## Risks / Trade-offs

- A full release build is long (workflow timeout is 360 minutes); the Bazel cache is the main lever.
- Ad-hoc signing needs a paid account and registered device UDIDs (up to 100 per year); without them the IPA cannot be installed.
- Which signing identity and device to use is the user's call (open question).

## Bundle identifier (user decision, 2026-10-28)

The user supplied `app.starfruit2689.orange1525` from an on-device signing screen and asked for it to be used. CI feeds the id through `MOKAGRAM_BUNDLE_ID` (`build-system/mokagram/prepare.py`). Whether the IPA is then re-signed by Sideloadly or another tool, the id inside it should already be this one so the app group and extensions do not depend on the re-signer rewriting it. The signing certificate seen in that screenshot belongs to a third party and can be revoked; it is not part of this change.
