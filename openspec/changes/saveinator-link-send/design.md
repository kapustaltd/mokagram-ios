## Context

Desktop `Mokagram::Saveinator`: `OfferSendDownload(controller, action, text, sendAsText, clearField)` returns true when it took over the send. It declines when already sending as text, the setting `saveinator.enabled` is off, the text is empty or contains whitespace, or `Normalized(text)` is not a supported link (`SupportedHost`). It shows `ChooseBox` and runs `Download(window, action, link, choice)` with `Choice { media, maxHeight }`. The API is an HTTPS endpoint authorised with a key that Desktop embeds in source.

iOS has no Saveinator code and no registry entry yet. Settings live in `MokoCore` registry (`MokoBuiltinSettings`); media sending exists for tracks in `MokoTrackSending.swift`.

## Goals / Non-Goals

**Goals:**
- Same trigger rules as Desktop; native iOS choice sheet; reuse the normal media-send path.

**Non-Goals:**
- Downloading arbitrary unsupported sites.
- Background downloads that survive app termination (decide later if needed).
- Caching of downloaded media beyond the normal send pipeline.

## Decisions

- **Pure link parser in `MokoCore`** (`normalized(_:)`, `isSupportedHost`) with tests; it carries the exact host list from Desktop.
- **Hook point**: the chat's text send path, just before a plain message is enqueued, with the same pattern as Desktop: the hook returns "handled", and passes closures for send-as-text and clear-field. The send options are captured at press time.
- **Choice UI** is a native action sheet / bottom sheet; options mirror Desktop's `MediaTitles()` and quality choices.
- **Client credentials**: Desktop commits the API key in source. For iOS the key is treated as a secret: read from build configuration/app config, never written into specs, logs or the repo history beyond what is unavoidable. Where it comes from needs the user's decision (see risks).
- **The context-menu action is an assumption.** The user answered "yes" to a question that offered both paths; only the send-time offer is in scope unless they confirm the menu action.

## Risks / Trade-offs

- Embedded API key can be extracted from the IPA; server-side rate limiting is the only real protection.
- Large downloads and memory: stream to a temp file, do not hold the whole video in memory.
- Upload of the result must respect the account's file size limits and show a clear error otherwise.
