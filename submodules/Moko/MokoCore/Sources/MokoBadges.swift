import Foundation

/// mokaGram verification badges, as on Desktop (`Mokagram::Badges`): a user is a developer, a holder
/// of the badge ("sub") or neither. The icon is a custom emoji, the same ones Desktop draws, so every
/// surface that already draws a bot-verification icon shows it.
///
/// The lookup is a pure read of an in-memory set (lock protected), safe from list layout off the
/// main thread. The set is loaded from the on-device cache on first use and replaced only by a
/// refresh that parsed successfully, so a failed or malformed refresh never removes known badges.
public enum MokoBadges {
    public enum Kind: Equatable {
        case none
        case developerEcronx
        case developerXdshkaaa
        case sub
    }

    /// Developers by user id. `6612638154` is `@ecronx` (confirmed by the user; it is Desktop's `kOwnerId`).
    /// TODO: `@xdshkaaa`'s numeric id is not recorded anywhere readable; add it to `developerXdshkaaaIds`
    /// once known. Until then that developer is matched by username.
    static let developerEcronxIds: Set<Int64> = [6612638154]
    static let developerEcronxUsername = "ecronx"
    static let developerXdshkaaaIds: Set<Int64> = []
    static let developerXdshkaaaUsername = "xdshkaaa"

    /// Custom emoji of the icons. `ecronx` and the shared icon are the ids Desktop uses.
    /// TODO(placeholder): `@xdshkaaa` has no artwork of its own yet; it must differ from the other icons
    /// (task 1.2), so a neighbouring emoji id stands in until the real emoji id is supplied.
    public static let iconEcronx: Int64 = 5397879498492389616
    public static let iconXdshkaaaPlaceholder: Int64 = 5397879498492389617
    public static let defaultSubIcon: Int64 = 5402618655601109041

    public static let changedNotification = Notification.Name("MokoBadgesChanged")

    static let cacheKey = "moko.badges.cache.v1"
    /// https only (ATS blocks Desktop's plain-http IP mirror on iOS).
    static let sources: [URL] = [
        URL(string: "https://raw.githubusercontent.com/ecronxy/mokagram/badges/badges.json")!
    ]
    static let minimumRefreshInterval: TimeInterval = 60

    struct Parsed: Equatable {
        var iconId: Int64?
        var users: Set<Int64>
    }

    private static let lock = NSLock()
    private static var loaded = false
    private static var users: Set<Int64> = []
    private static var subIcon: Int64 = defaultSubIcon
    private static var lastRefresh: Date?
    private static var inFlight = false

    /// Parses `{"emoji_id": "...", "users": [id, ...]}`; nil for anything that is not that shape.
    static func parse(_ data: Data) -> Parsed? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let list = object["users"] as? [Any] else {
            return nil
        }
        var users = Set<Int64>()
        for value in list {
            if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.int64Value > 0 {
                users.insert(number.int64Value)
            } else if let text = value as? String, let id = Int64(text), id > 0 {
                users.insert(id)
            }
        }
        var icon: Int64?
        if let text = object["emoji_id"] as? String {
            icon = Int64(text)
        } else if let number = object["emoji_id"] as? NSNumber {
            icon = number.int64Value
        }
        if let value = icon, value <= 0 {
            icon = nil
        }
        return Parsed(iconId: icon, users: users)
    }

    private static func loadIfNeeded() {
        if loaded {
            return
        }
        loaded = true
        if let data = MokoStorage.defaults.data(forKey: cacheKey), let parsed = parse(data) {
            users = parsed.users
            subIcon = parsed.iconId ?? defaultSubIcon
        }
    }

    public static func kind(userId: Int64, username: String? = nil) -> Kind {
        if developerEcronxIds.contains(userId) {
            return .developerEcronx
        }
        if developerXdshkaaaIds.contains(userId) {
            return .developerXdshkaaa
        }
        if let username = username?.lowercased() {
            if username == developerEcronxUsername {
                return .developerEcronx
            }
            if username == developerXdshkaaaUsername {
                return .developerXdshkaaa
            }
        }
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        return users.contains(userId) ? .sub : .none
    }

    /// The custom emoji to draw next to the user's name, nil when the user has no mokaGram badge.
    public static func iconFileId(userId: Int64, username: String? = nil) -> Int64? {
        switch kind(userId: userId, username: username) {
        case .none:
            return nil
        case .developerEcronx:
            return iconEcronx
        case .developerXdshkaaa:
            return iconXdshkaaaPlaceholder
        case .sub:
            lock.lock()
            defer { lock.unlock() }
            return subIcon
        }
    }

    /// Replaces the holder set from fetched data. Malformed data changes nothing. Returns whether the list changed.
    @discardableResult
    static func apply(_ data: Data) -> Bool {
        guard let parsed = parse(data) else {
            return false
        }
        lock.lock()
        loadIfNeeded()
        let newIcon = parsed.iconId ?? defaultSubIcon
        let changed = users != parsed.users || subIcon != newIcon
        users = parsed.users
        subIcon = newIcon
        lock.unlock()
        MokoStorage.defaults.set(data, forKey: cacheKey)
        return changed
    }

    /// Fetches the list in the background; throttled, so it is safe to call on launch and on every foreground.
    public static func refresh(force: Bool = false) {
        lock.lock()
        if inFlight || (!force && lastRefresh.map({ Date().timeIntervalSince($0) < minimumRefreshInterval }) == true) {
            lock.unlock()
            return
        }
        inFlight = true
        lastRefresh = Date()
        lock.unlock()
        fetch(index: 0)
    }

    private static func fetch(index: Int) {
        if index >= sources.count {
            // Every https source failed: ask @mokagent through the signed-in account, if the app registered one.
            lock.lock()
            let fallback = inlineFallback
            lock.unlock()
            guard let fallback else {
                finish(data: nil)
                return
            }
            fallback { data in
                finish(data: data)
            }
            return
        }
        var request = URLRequest(url: sources[index], cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8.0)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let data, (response as? HTTPURLResponse)?.statusCode == 200, parse(data) != nil {
                finish(data: data)
            } else {
                fetch(index: index + 1)
            }
        }.resume()
    }

    private static func finish(data: Data?) {
        var changed = false
        if let data {
            changed = apply(data)
        }
        lock.lock()
        inFlight = false
        lock.unlock()
        if changed {
            NotificationCenter.default.post(name: changedNotification, object: nil)
        }
    }

    /// Fallback used when no https source answers: delivers `badges.json`-shaped data, or nil. The app
    /// registers it once an account exists (Desktop's `badges:N` inline queries to `@mokagent`).
    public static func setInlineFallback(_ fallback: ((@escaping (Data?) -> Void) -> Void)?) {
        lock.lock()
        inlineFallback = fallback
        lock.unlock()
    }

    private static var inlineFallback: ((@escaping (Data?) -> Void) -> Void)?

    static func _resetForTesting() {
        lock.lock()
        loaded = false
        users = []
        subIcon = defaultSubIcon
        lastRefresh = nil
        inFlight = false
        lock.unlock()
    }
}
