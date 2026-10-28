## 1. Define the feature (blocking)

- [x] 1.2 Read Desktop `docs-plugins-api.md` and the plugin host sources and write the iOS design (research in design.md; not approved)
- [ ] 1.1 Get answers to the open questions in design.md from the user (Q1 runtime, Q2 distribution, Q3 scope, Q4 compatibility, Q5 capabilities first, Q6 security, Q7 UI)
- [ ] 1.3 Rewrite `specs/plugins-port/spec.md` from the DRAFT requirements with approved ones and replace the tasks below

## OUTLINE (NOT APPROVED, assumes the recommended options; do not start before 1.1 and 1.3)

## 2. Spike (decides Q1 feasibility)

- [ ] 2.1 Build CPython 3.13+ iOS XCFramework (Python-apple-support), integrate into Bazel as a prebuilt framework; measure IPA growth and cold launch
- [ ] 2.2 Run Desktop `py/host.py` + `sdk_api.py` + `fw.py` unchanged against a fake bridge in the simulator; list stdlib gaps (ssl CA store, secrets, ctypes)
- [ ] 2.3 Decide on http (bundled CA vs `URLSession` bridge op) and secrets (Keychain bridge op); propose the SDK changes to Desktop

## 3. Host and bridge

- [ ] 3.1 `submodules/Moko/MokoPlugins`: vendored `py/` snapshot (read-only), interpreter lifecycle, worker thread, hook queue, timeouts, log drain
- [ ] 3.2 Swift `BridgeFn(op, json)` for the 37 Desktop ops, grouped by feature; main-thread marshalling; explicit account selection
- [ ] 3.3 Grants, hashes, audit log, limits, global switch, safe mode; unit tests on the Foundation-only policy layer
- [ ] 3.4 Ghost/Guard policy check in bridge actions; per-account data separation

## 4. Install and UI

- [ ] 4.1 Settings > mokaGram > Plugins: list, enable/disable, logs, global switch (`MokoPluginsUI`)
- [ ] 4.2 Install window (permissions, detected warnings), install from file / link / `.loadmod`
- [ ] 4.3 Dialogs, toasts, bulletins, plugin settings page (`create_settings`)

## 5. Features by priority

- [ ] 5.1 Commands in the composer, `.help`, `.plugins`, `.config`, `.logs`
- [ ] 5.2 Message events, watchers, core actions (send/edit/get/history/chat_info/me)
- [ ] 5.3 Menu points (message, chat, profile, attach, header, composer) and `cron`/timers
- [ ] 5.4 Message hooks (text, badge, filter) with cached results
- [ ] 5.5 `invoke_raw`/TL policy, chat admin, privacy, profile, folders

## 6. Store and update

- [ ] 6.1 Signed catalog client: Ed25519 verify with the Desktop public key, SHA-256 and size check, safe file name
- [ ] 6.2 Store UI, auto-update every 12 h with silent-only-if-no-new-permissions, backup / restore

## 7. Verification

- [ ] 7.1 Compatibility suite: `examples/showcase.plugin` and all store plugins on iOS
- [ ] 7.2 Policy tests (limits, grants, hash change, signature failure), device checks, Ghost leak check on real traffic
- [ ] 7.3 Compile-out flag build; document the iOS differences table
