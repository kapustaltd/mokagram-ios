## Context

Desktop: `Mokagram::Badges` loads `badges.json` (`{"emoji_id": "...", "users": [id, ...]}`) from an IP mirror and the `badges` branch on GitHub, falls back to paged inline queries `badges:N` to `@mokagent` (44 users per page), caches to `tdata/moka_badges_cache.json`, and sets `UserData::botVerifyDetails` with a synthetic value so the stock UI draws it.

iOS: no such hook. `isVerified` is read in about 38 files (`PeerUtils.swift:216` for `Peer`, `Peer.swift:512` for `EnginePeer`); each draws `PresentationResourcesChatList` verified icons, so the icon is not one shared view. The mokaGram storage layer is `submodules/Moko/MokoCore` (`MokoStorage`, app-group settings).

## Goals / Non-Goals

**Goals:**
- One decision point that maps a user id to `none | developer(ecronx) | developer(xdshkaaa) | sub`.
- The existing verified-icon call sites ask it instead of reading `isVerified` directly where they draw an icon.

**Non-Goals:**
- Issuing or revoking badges (that is the badge bot's job).
- Changing Telegram's verification semantics, or the "verified" flag used for non-visual logic (scam, reply rules).
- Custom icons for channels/groups.

## Decisions

- **Decision point in MokoCore**, a pure lookup `MokoBadges.kind(for: PeerId)` backed by an in-memory set loaded from the cache, so it is safe to call from list layout off the main thread. Call sites in non-Moko modules reach it through a small protocol/closure registered at launch, to avoid a dependency cycle (same pattern as `MokoArtworkRegistry`).
- **Developer ids are resolved by user id, not username**, because usernames can change. Ids to be taken from Desktop's source (to verify during implementation; usernames are the only thing given in the request).
- **Drawing**: extend the verified-icon factory to take a `kind` and return the matching image; icons are bundled vector assets tinted for the theme where Desktop's are tinted.
- **Neighbor descriptors / relayout**: a list row that shows an icon must publish the badge kind in its descriptor or equality, otherwise a late list refresh does not relayout rows (see the Neighbor descriptors section in CLAUDE.md for the general rule).
- **Refresh trigger**: on launch and on return to foreground, throttled; on change, post a notification so visible rows reload.

## Risks / Trade-offs

- The list endpoint is a raw IP over `http://` on Desktop. ATS blocks plain http on iOS: needs an https mirror or the GitHub raw URL plus the `@mokagent` path as primary. Decide during implementation.
- A large holder list kept as a set costs little; a fetch on every foreground would not, hence the throttle.
- Icon artwork for the two personal icons does not exist in the iOS repo yet and has to come from Desktop or the user.
