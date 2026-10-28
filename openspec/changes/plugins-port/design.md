## Context

STATUS: research draft. Nothing in this file is decided by the user. Every item marked
"Recommendation" is the researcher's proposal only. The open questions stay open until the user answers them.

NOTE ON PRIOR TEXT: `port-mokagram-desktop/design.md` section 4.10 (and 7, 10) already records
"embedded CPython, same `.plugin` files, same store, ad-hoc distribution" as "decided". The plugins-port
change was opened because the user states nothing about iOS plugins was actually decided. Treat 4.10 as a
proposal to be re-confirmed (Q1 and Q2 below), not as a settled fact.

### How Desktop plugins work (from the sources, read-only)

Sources: `Telegram/SourceFiles/mokagram/plugins/` (C++ ~5.3k lines, Python ~6k lines, generated TL schema
~15k lines), `docs-plugins-api.md`, `examples/showcase.plugin`.

**Host.** CPython is embedded in the client (`Py_InitializeEx`, then the GIL is released and every call uses
`PyGILState_Ensure`). `mokagram_plugins.cpp` loads the Python helper scripts (`tl_names`, `host`, `fw`, ... as
string constants generated from `py/*.py` by `gen_inc.sh`) into `__main__`, and exposes a single native
function `_moka_native(op, json)` to Python. A single worker thread runs observing hooks from a bounded
queue (256 items, drops when full); callbacks have a 5 s timeout. The C++ side also keeps a per-plugin
filter of TL constructor ids so that update hooks are only queued for subscribed plugins. Plugin output
(`print`, logger) is drained into the client log.

**Python side (`py/`).** `host.py`: parses plugin metadata with `ast` without executing the file, detects
used capabilities statically (imports of `requests/urllib/socket`, `open`, `exec`, SDK method names),
registry of plugins, per-plugin state, enable/disable/pin, hook chain with `HookResult` strategies
(DEFAULT, CANCEL, MODIFY, MODIFY_FINAL), grants and audit. `base_plugin.py`: `BasePlugin`, `command`,
`watcher`, `HookResult`, `MenuItemData`, settings widgets (`Header`, `Switch`, `Selector`, `Input`,
`Text`, `Button`, `Password`). `sdk_api.py` (`mokagram_sdk.api`, alias `moka`): about 100 functions
(messages, dialogs, history, participants, chat admin, folders, privacy, profile, TL invoke, http,
db, secrets, cron/timers, dialogs/toasts/bulletins). `fw.py`: higher level framework (commands, async
commands, watchers, cron, backup/restore zip, the no-code plugin constructor). `tl.py`/`tl_schema`: TL codec
and policy for `invoke_tl` (auth/payments/passwords/sessions/passport/phone/bots blocked; read vs write
split by method name; FLOOD_WAIT retry).

**Bridge (client side, `mokagram_plugin_api.cpp`).** About 37 ops handled by the Qt client: `send_message`,
`edit_message`, `get_history`, `get_dialogs`, `chat_info`, `get_user_info`, `get_me`, `pin_message`,
`delete_messages`, `send_file`, `send_album`, `download_media`, `open_chat`, `open_url`, `copy_text`,
`clipboard_get`, `mark_read`, `dialog_show/update/close`, `toast`, `bulletin`, `settings_register`,
`setting_get/set`, `client_setting_get`, `client_data_dir`, `client_lang`, `events_subscribe`,
`filter_subscribe`, `invoke_raw` (pre-serialized TL bytes), `tl_input`, `install_plugin_file`,
`plugin_unloaded`, `run_main`. Anything touching the UI or session is marshalled to the main thread.
Return path into Python: hooks, menu item click, message filter / badge / text hooks, `Invoke`.

**API surface** (`docs-plugins-api.md`): events (`on_new_message`, edited, deleted, reaction, sent,
chat opened, peer updated, user status, typing, chat action, read, story, album, app event), actions,
commands (`@command`, async, `ctx.edit/reply`), watchers (`@watcher` with filters), UI points (header
and composer buttons, message / chat / profile / attach / drawer menus), dialogs and toasts, settings page,
storage / db / secrets / http / cron, `invoke_tl`, and message hooks (filter = hide, badge = text next
to the time, text = replace the displayed text, `userpic` entity).

**Permissions.** Declared in `__permissions__`; granted at install in a window. Always allowed (L0):
`ui, storage, settings, background`. Never granted (L4): `raw_api, native, files.any, network.any,
subprocess`. Others: `messages.read/send/edit/delete`, `tl.read/tl.write`, `clipboard`, `network`, `files`,
`chats.manage`, `chats.settings`, `profile.write`, `privacy.write`. Without a grant an SDK call returns
`None`. Grants are stored per plugin id together with the SHA-256 of the plugin file; a changed file must
be re-approved. Limits: 300 actions/min per plugin plus per-action limits, 60 TL calls/min, 30 http
requests/min, http blocks internal addresses and caps responses at 20 MB, file paths limited to the plugin
data dir or temp. Every action goes to `plugin_audit.log` (5 MB x 3 rotation).
IMPORTANT FINDING: enforcement is cooperative inside the SDK. The plugin is plain Python running in the
client process; I found no import blocker or audit hook (grep of `host.py` for `meta_path`/`addaudithook`
finds nothing). The static scan only warns at install. So a hostile plugin that imports `ctypes`/`os`
directly bypasses the permissions on Desktop. The permission model is a consent and accident guard, not a sandbox.

**Store and install.** Store = a signed catalog in the GitHub repo `ecronxy/mokagram-plugins`
(`index.json` plus `index.json.sig`). The signature is Ed25519 over `"mokagram-plugins\n" + index`, verified
with the key embedded in `update/mokagram_update.cpp`. Each entry has `id, name, version, file, permissions,
sha256, size, icon, details`. Client limits: index 256 KB, plugin 2 MB, file name regex
`^[A-Za-z0-9_][A-Za-z0-9_.-]{0,80}\.plugin$`, cache-busting query string, no unsafe redirects. A file is
installed only if its SHA-256 matches the signed entry. Install window shows metadata, requested and detected
permissions. Auto-update every 12 h (silent only if no new permissions). `.loadmod` (reply to a `.plugin`
file or a link), `.backup` to Saved Messages, "create plugin" no-code constructor, developer mode with
hot reload.

### Platform facts relevant to iOS

- Apple App Review Guideline 2.5.2 (fetched from developer.apple.com): apps "may not ... download, install, or
  execute code which introduces or changes features or functionality of the app". Exception only for
  educational / code-learning apps. Guideline 4.7 separately allows "HTML5 and JavaScript mini apps ... and
  plug-ins" not embedded in the binary, but with duties (4.7.1 privacy, filtering and reporting, 4.7.2 no
  exposing native platform APIs to such software without Apple permission, 4.7.3 no sharing data or
  permissions per item without explicit consent each time, 4.7.4 index of software, 4.7.5 age limits).
  Python plugins are not covered by the 4.7 wording. Conclusion: Desktop-style downloaded Python plugins that
  read and send messages are not publishable through App Review in my reading; a JavaScript variant is a
  gray area at best (4.7.2 conflicts with a rich native API). Enforcement is case-by-case, so this is a
  risk assessment and not legal advice.
- The repo ships ad-hoc (README, `.github/workflows/build.yml`: `Mokagram-adhoc`, up to 100 registered
  devices, no App Store, no external TestFlight). Ad-hoc builds are not reviewed by App Review, so 2.5.2 is
  not enforced there, but the Apple Developer Program License Agreement still governs and a later move to
  TestFlight / App Store would make the plugin host a blocker. A build flag that compiles the host out would
  keep that door open.
- CPython officially supports iOS since 3.13 (PEP 730, Tier 3): XCFramework, embedded use only, no
  `subprocess`/`fork`, `sys.platform == "ios"`; extension modules must be packaged as frameworks;
  pure-Python downloaded code is fine technically (iOS code signing only blocks new native code). BeeWare
  `Python-apple-support` builds the XCFramework. Size is roughly tens of MB (the earlier 30-50 MB guess in
  port-mokagram-desktop is unmeasured).
- iOS has no JIT problem for CPython (interpreter only). JavaScriptCore is a system framework (0 MB), and
  on a non-JIT-entitled app runs in interpreter mode; no extra entitlement.
- Repo already has `third-party/wamr` (WASM interpreter used by tgcalls v2wasm).
- Where a host would live: new Foundation-only module `submodules/Moko/MokoPlugins` (permissions, grants,
  store index verification, install policy; host tests like `MokoCoreTests`), plus `MokoPluginsUI`
  (settings pages, install window) next to `MokoSettingsUI`, and the bridge wiring in the app layer where
  `AccountContext` is available (TelegramCore must not import UIKit). Desktop `py/` would be vendored as a
  read-only snapshot like `Telegram/WatchApp` (fixes go to Desktop, then re-sync).

### iOS-specific hazards found in the Desktop sources

- `api.secrets` uses `secret-tool`/encrypted file: must map to Keychain (bridge op or SDK edit).
- `api.http` uses `urllib`/`ssl`: embedded iOS Python has no system CA store; needs bundled CA bundle or
  routing http through `URLSession` via a bridge op (an SDK change, so it must land in Desktop too).
- Multi-account: Desktop plugins act on the active account; iOS can have several. The bridge must pick the
  account explicitly and plugin data must be separated per account or declared global.
- Ghost mode and Guard: plugin actions `mark_read`, `send_message`, typing must pass through the same
  privacy policy; otherwise a plugin leaks what Ghost hides.
- Background: Python callbacks only run while the app runs (cron/intervals as in 4.10); notification
  service extension must not load the host (memory limit).
- Memory / launch: start the interpreter lazily on first enabled plugin.
- Hooks on message text/badge/filter need cached synchronous results on the UI thread (50 ms budget on
  Desktop); the CoreList / ListView item nodes must read a cache, never call into Python.

## Goals / Non-Goals

**Goals:**
- Give the user a decision-ready set of options for each open question.
- Keep Desktop reference facts in one place so the spec can be written fast.

**Non-Goals:**
- No implementation, no code, no build, until the open questions are answered.
- This document does not decide anything on the user's behalf.

## Decisions

None. All decisions are pending user answers. See Open Questions (each with options and a recommendation).

## Open Questions

### Q1. Language and runtime

| Option | What | Pros | Cons |
| --- | --- | --- | --- |
| A. Embedded CPython 3.13+ (PEP 730) | Desktop `py/` as is | Same `.plugin` files, same SDK, no SDK rewrite, one source of truth; `py/` is already tested on Desktop | Large binary (tens of MB, to be measured); Bazel integration of an XCFramework + stdlib frameworks; cannot be App Store compliant; CA store and Keychain gaps; no real sandbox |
| B. JavaScriptCore | New JS SDK, new plugin format | System framework (0 MB); the only form Apple's 4.7 mentions ("JavaScript mini apps / plug-ins"); can restrict globals to a whitelist (real capability sandbox) | Full rewrite of ~6k lines SDK; Desktop plugins do not run; plugin authors need to write twice; 4.7.2 still limits native API exposure |
| C. WASM (WAMR already vendored) | Plugins compiled to wasm | Real sandbox, language-agnostic | Worst author experience; huge SDK rewrite; no ecosystem |
| D. Swift-only built-in "plugins" | Features shipped in the binary, toggled by the user | App Store safe, trivial | Not user-extensible; not a plugin system |

Recommendation: A, given the user already wanted Desktop compatibility (4.10), the ad-hoc channel, and
that A is the only option where "one plugin runs on both" is true by construction. Keep the host behind
the `BridgeFn`-style boundary so B can be added later without touching the UI. Spike first (see tasks):
measure IPA growth, launch cost, and whether `host.py` runs unchanged.

### Q2. Distribution target

| Option | Effect |
| --- | --- |
| A. Ad-hoc only (current CI) | No review, 2.5.2 not enforced; plugins from the store allowed; max 100 devices/year |
| B. App Store / TestFlight too | Needs the plugin host removed or restricted to bundled signed plugins; JS-only at best; not realistic with message-reading APIs |
| C. Both via a build flag | Two variants of the binary: the store variant compiles the host out (or bundled-only) |

Recommendation: A now (matches README and 4.10), written so C stays possible (a single compile-time
flag and no hard dependency of other Moko features on the host). Ask the user to confirm A explicitly.

### Q3. Scope of installation

| Option | Notes |
| --- | --- |
| A. Bundled only | Smallest; barely a plugin system |
| B. Files (`.plugin` via Files/Share/`.loadmod`) + bundled samples | Cheap, no network trust issue beyond install window |
| C. B + signed store + auto-update | Full parity with Desktop, needs the Ed25519 key and the `mokagram-plugins` repo |

Recommendation: C, delivered in stages: B first (host, install window, permissions), then the store and
update (reuse Desktop index format and the Ed25519 public key from `mokagram_update.cpp`; CryptoKit
`Curve25519.Signing` verifies Ed25519).

### Q4. Desktop API compatibility

| Option | Notes |
| --- | --- |
| A. Full: same metadata, SDK, permissions, store | Plugin authors write once; follow Desktop SDK versions; iOS differences exposed only via `platform == "ios"` and documented gaps |
| B. Subset: documented list of supported calls, rest raise "unsupported" | Faster; plugin may half-work |
| C. New iOS API | Clean but forks the ecosystem |

Recommendation: A with an explicit compatibility table (supported / differs / unsupported, e.g.
developer-mode hot reload, `secret-tool`, drawer menu) and graceful `None`/error returns for
unsupported calls. Platform additions go into Desktop at the same time.

### Q5. Capabilities first (ordering)

Recommendation, by value and risk:
1. Host lifecycle, install window, grants, audit log, kill switch, per-plugin enable/disable, logs.
2. Commands in the composer (`@command`, `.help`, `.plugins`), toasts, dialogs, settings page, `api.db`,
   `api.storage`, `api.http`.
3. Message events (`on_new_message`, `on_message_sent`, watchers) and actions (`send_message`,
   `get_message`, `edit_message`, `get_history`, `chat_info`, `get_me`).
4. Menu points (message / chat / profile / attach) and `cron`.
5. Message hooks (text / badge / filter), `userpic` entity.
6. `invoke_tl` / `invoke_raw`, chat admin, privacy, profile, folders, backup / restore.
Alternative ordering (UI-first or TL-first) is possible if the user has a specific plugin in mind; ask
which concrete plugins they need to run.

### Q6. Security model

| Option | Notes |
| --- | --- |
| A. Desktop model: consent window + SDK-level permission gate + audit log + hash-bound grants + signed store | Honest limit: not a sandbox; relies on trust in the store signer and on the user |
| B. A + hardening: block dangerous imports (`ctypes`, `os.system`, `socket` for non-granted) via audit hook / import hook, cap memory and run time, safe mode after crash loop, no `network`/`files` default | Raises the bar for sloppy or malicious plugins; still bypassable in-process |
| C. Out-of-process or WASM/JS capability sandbox | Real isolation; not available for CPython on iOS (no processes) |

Recommendation: B. Additional iOS rules: plugin actions go through Ghost / Guard policy; read access is
per account; Keychain for secrets; unsigned file install shows a stronger warning; store plugins require
signature plus hash; global off switch and "safe mode" at launch. Ask whether a user-installed plugin may
get the same permission level as in Desktop, or whether `tl.write` and `chats.manage` should be off by
default on iOS.

### Q7. UI placement

| Option | Notes |
| --- | --- |
| A. Settings > mokaGram > Plugins (list, store, install, per-plugin page) | Matches 4.10 table (drawer menu -> Settings) and `MokoSettingsUI` |
| B. Own tab or main-menu entry | More discoverable, bigger change to the app shell |
| C. A + plugin menu points inside existing menus | Plugin-defined items appear in message / chat / profile / attach menus, composer buttons |

Recommendation: C (A for management, items live where `MenuItemType` says). Header button -> chat
"..." menu; composer button -> attach menu or bar above keyboard (per 4.10).

## Risks / Trade-offs

- App Review: any App Store route is closed for plugins that download code and read messages (2.5.2,
  4.7.2). Mitigation: ad-hoc channel and a compile-out flag.
- Binary size and launch time with CPython are unmeasured: spike before committing.
- Hostile plugin is not stopped by an in-process model; ad-hoc devices are the user's own, and store signing is the main defense.
- Desktop SDK drift: vendor `py/` as a snapshot and pin a version; add a compat test suite
  (`examples/showcase.plugin`, store plugins).
- Privacy: plugins can read every message of the account; Ghost and multi-account rules must be enforced in the bridge.
- Plugin hooks run Python on a worker thread; UI hooks must be cache-backed to never stall scrolling.
- Maintenance: a 37-op Swift bridge must follow the Desktop op list.

## Sources

- Apple App Review Guidelines 2.5.2 and 4.7: https://developer.apple.com/app-store/review/guidelines/
- PEP 730 (iOS support): https://peps.python.org/pep-0730/
- BeeWare Python-apple-support: https://github.com/beeware/Python-apple-support

## Decisions confirmed by the user (2026-10-28)

- Runtime: embedded CPython, same `.plugin` files and same store as Desktop; a spike (app size, launch, `host.py` running unchanged) comes before final approval.
- Distribution: IPA sideloaded with Sideloadly only, no App Store. The optional build flag that strips the host is therefore not required (the user's choice, recorded as option A).
- Scope: files and links first, the signed store with auto-update second. Specific first plugins: not named yet.
- Security: Desktop model plus hardening; `tl.write` and `chats.manage` off by default on iOS.
- UI: Settings → mokaGram → Plugins, plus plugin items in existing menus.

## Sideloadly constraint (to check in the spike)

Sideloadly re-signs the IPA with the user's own Apple ID, which can change the bundle id and team and strip entitlements. Anything that depends on an app group or extension entitlement (Moko settings in the app group, notification extension) must be checked on a Sideloadly-installed build.
