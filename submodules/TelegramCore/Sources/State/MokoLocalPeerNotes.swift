import Foundation

// iOS adaptation of mokaGram's local peer notes. These values are not sent to Telegram.
public struct MokoLocalPeerNote: Equatable {
    public var tag: String
    public var note: String

    public init(tag: String, note: String) {
        self.tag = tag
        self.note = note
    }
}

public enum MokoLocalPeerNotes {
    public static let changed = Notification.Name("mokoGram.peerNoteChanged")
    private static func key(accountId: Int64, peerId: Int64) -> String {
        return "mokoGram.peerNote.\(accountId).\(peerId)"
    }

    public static func load(accountId: Int64, peerId: Int64, defaults: UserDefaults = .standard) -> MokoLocalPeerNote {
        let value = defaults.dictionary(forKey: key(accountId: accountId, peerId: peerId))
        return MokoLocalPeerNote(tag: value?["tag"] as? String ?? "", note: value?["note"] as? String ?? "")
    }

    public static func save(accountId: Int64, peerId: Int64, tag: String, note: String, defaults: UserDefaults = .standard) {
        let normalizedTag = String(tag.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").prefix(24))
        let normalizedNote = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        let storageKey = key(accountId: accountId, peerId: peerId)
        if normalizedTag.isEmpty && normalizedNote.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(["tag": normalizedTag, "note": normalizedNote], forKey: storageKey)
        }
        NotificationCenter.default.post(name: changed, object: nil, userInfo: ["accountId": accountId, "peerId": peerId])
    }
}
