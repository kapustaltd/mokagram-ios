## 1. Prepare

- [ ] 1.1 Confirm the branch/commit to build and that the other changes are merged or intentionally excluded
- [ ] 1.2 Set `MOKAGRAM_BUNDLE_ID` to `app.starfruit2689.orange1525` (build configuration and CI secret) and check app group / keychain group / extension ids derive from it
- [ ] 1.3 Confirm signing kind with the user (ad-hoc with secrets vs unsigned) and the target device

## 2. Build

- [ ] 2.1 Run the release build (CI dispatch or local `Make.py build --configuration=release_arm64`) with a build number
- [ ] 2.2 Fix release-only failures, if any, in their own commits
- [ ] 2.3 Collect `Telegram.ipa`, dSYMs and the SHA-256

## 3. Verify

- [ ] 3.1 Check `CFBundleVersion`, that `CFBundleIdentifier` is `app.starfruit2689.orange1525` for the app and its extensions, and the signing of the IPA
- [ ] 3.2 Install on a registered device; launch, sign in, open a chat, play a track
- [ ] 3.3 Run `third-party/mtproto-engine/scripts/verify-ios-link.sh` on the unstripped binary (hardware crypto, single std)

## 4. Document

- [ ] 4.1 Add the local release command and the signing note to `CLAUDE.md`
