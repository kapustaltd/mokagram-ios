import Foundation

/// Streamer mode masking, matching Desktop `mokagram/streamer/mokagram_streamer.cpp`.
/// Pure functions: whether a field is hidden right now is decided by `isActive`, which reads the
/// `streamer.*` settings, and the UI layer applies `mask` to what it shows.
public enum MokoStreamer {
    public enum Field: CaseIterable {
        case phone
        case username
        case link
        case id
        case name
        case notify

        var settingKey: String {
            switch self {
            case .phone: return "streamer.phone"
            case .username: return "streamer.username"
            case .link: return "streamer.link"
            case .id: return "streamer.id"
            case .name: return "streamer.name"
            case .notify: return "streamer.notify"
            }
        }
    }

    /// What copying a hidden value puts on the pasteboard. The stored value is the index.
    public enum CopyMode: Int {
        case real = 0
        case block = 1
        case mask = 2
    }

    static let dot: Character = "\u{2022}"

    private static func dots(_ count: Int) -> String {
        return String(repeating: dot, count: max(0, count))
    }

    public static func isActive(_ field: Field, accountId: Int64) -> Bool {
        return MokoSettings.bool("streamer.enabled", accountId: accountId) && MokoSettings.bool(field.settingKey, accountId: accountId)
    }

    public static func copyMode(accountId: Int64) -> CopyMode {
        return CopyMode(rawValue: MokoSettings.int("streamer.copy", accountId: accountId)) ?? .real
    }

    /// The mask of `real`, without checking whether the field is active.
    public static func mask(_ field: Field, _ real: String) -> String {
        if real.isEmpty {
            return real
        }
        switch field {
        case .phone:
            // Digits only: the plus and the separators keep the shape of the number.
            return String(real.map { $0.isASCII && $0.isNumber ? dot : $0 })
        case .username:
            let hasAt = real.hasPrefix("@")
            let length = real.count - (hasAt ? 1 : 0)
            return (hasAt ? "@" : "") + dots(min(max(length, 5), 16))
        case .link:
            return maskUrl(real)
        case .id:
            return dots(9)
        case .name:
            return String(real.prefix(1)) + dots(3)
        case .notify:
            return real
        }
    }

    /// `https://t.me/name` becomes `https://t.me/••••••`; an address without a path is kept.
    public static func maskUrl(_ url: String) -> String {
        let hostStart: String.Index
        if let scheme = url.range(of: "://") {
            hostStart = scheme.upperBound
        } else {
            hostStart = url.startIndex
        }
        guard let slash = url[hostStart...].firstIndex(of: "/") else {
            return url
        }
        let afterSlash = url.index(after: slash)
        if afterSlash >= url.endIndex {
            return url
        }
        return String(url[..<afterSlash]) + dots(6)
    }

    /// What to put on the pasteboard for `real`: the real value, the mask, or nil when copying is blocked.
    public static func forCopy(_ field: Field, _ real: String, accountId: Int64) -> String? {
        guard isActive(field, accountId: accountId) else {
            return real
        }
        switch copyMode(accountId: accountId) {
        case .real:
            return real
        case .block:
            return nil
        case .mask:
            return mask(field, real)
        }
    }

    /// The text to show for `real`: masked when the field is active.
    public static func displayed(_ field: Field, _ real: String, accountId: Int64) -> String {
        return isActive(field, accountId: accountId) ? mask(field, real) : real
    }
}
