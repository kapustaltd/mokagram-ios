# Read-receipt port audit

The current toggle controls **automatic reads caused by viewing**. It is not complete Desktop ghost mode and does not promise invisibility.

- `ChatHistoryListNode` delegates visible-history reads to `AccountContext.applyMaxReadIndex`; the latter checks the account/peer policy before both peer and thread reads.
- `InstallInteractiveReadMessagesAction` can mark newly stored visible messages and consume mentions; its callback checks the same policy before performing those updates.
- Profile exceptions use the peer ID and apply to all discussion threads under that peer. A normal-user profile does not identify a separate secret-chat peer.
- Manual mark-as-read, notification actions, Siri, media consumption, already queued operations, read activity from other sessions, and server-side effects are not suppressed by this toggle.
- Existing chat-list context menus call `togglePeersUnreadMarkInteractively` and `markForumThreadAsRead` for explicit marking; neither is intercepted by the automatic-view gate.
- Network operations still requiring specific investigation include `SynchronizePeerReadState`, `ManagedConsumePersonalMessagesActions`, `ManagedSynchronizeConsumeMessageContentsOperations`, `ManagedSynchronizeMarkAllUnseenPersonalMessagesOperations`, `AccountViewTracker`, and secret-chat outgoing operations. Suppressing their requests without reconciling pending local state could silently flush receipts later or break self-destruct behavior.
- Enabling/disabling and exception changes while a chat is already open require device verification, including incoming messages, unread counts, discussion threads and subsequent read synchronization.
