import Foundation

/// Small helpers from Desktop `mokagram/misc/mokagram_misc.cpp`.
public enum MokoMisc {
    /// "Copy with author": `[dd.MM.yyyy HH:mm] author: text`.
    public static func copyWithAuthor(date: Date, author: String, text: String, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return "[\(formatter.string(from: date))] \(author): \(text)"
    }

    /// The probable owner of a sticker set, read from the high bits of the set id. This is a
    /// heuristic: it reproduces how the id was minted, not a record of ownership.
    public static func probableStickerSetOwnerId(setId: UInt64) -> UInt64 {
        var owner = setId >> 32
        if ((setId >> 16) & 0xFF) == 0x3F {
            owner |= 0x80000000
        }
        if ((setId >> 24) & 0xFF) != 0 {
            owner += 0x100000000
        }
        return owner
    }
}
