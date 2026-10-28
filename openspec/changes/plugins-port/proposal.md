## Why

Desktop mokaGram has a plugin system (Python plugins, a plugin store, an SDK). The user wants it on iOS as its own feature. It is unrelated to music and has not been designed yet: this change only records the intent and the open questions.

## What Changes

- Intent only: bring the mokaGram plugin system to iOS.
- No design or implementation decisions are made here. Open questions are listed in `design.md`.

## Capabilities

### New Capabilities

- `plugins-port`: placeholder; requirements will be written after the open questions are answered.

### Modified Capabilities

None.

## Impact

Unknown until designed. Desktop reference: `Telegram/SourceFiles/mokagram/plugins/` (C++ host `mokagram_plugins.cpp`, `mokagram_plugin_api.cpp`, `mokagram_plugin_install.cpp`, `mokagram_plugin_store.cpp`, Python side `py/host.py`, `py/base_plugin.py`, `py/sdk_api.py`, `py/tl*.py`) and `docs-plugins-api.md`. The existing `port-mokagram-desktop` inventory notes that plugin execution on iOS "must be assessed individually".
