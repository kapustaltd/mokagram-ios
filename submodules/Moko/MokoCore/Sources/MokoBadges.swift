import Foundation
import os

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
        /// The other developers (`xdshka`, `litteraliy`): the role and the blue icon, no icon of their own.
        case developer
        case sub
    }

    /// Developers by user id. `6612638154` is `@ecronx` (confirmed by the user; it is Desktop's `kOwnerId`).
    /// TODO: `@xdshkaaa`'s numeric id is not recorded anywhere readable; add it to `developerXdshkaaaIds`
    /// once known. Until then that developer is matched by username.
    static let developerEcronxIds: Set<Int64> = [6612638154]
    static let developerEcronxUsername = "ecronx"
    static let developerXdshkaaaIds: Set<Int64> = []
    static let developerXdshkaaaUsername = "xdshkaaa"
    /// Developers matched by username only, as on Desktop; they draw the blue icon (`iconEcronx`).
    static let developerUsernames: Set<String> = ["xdshka", "litteraliy"]

    /// Custom emoji of the icons. `ecronx` and the shared icon are the ids Desktop uses.
    /// TODO(placeholder): `@xdshkaaa` has no artwork of its own yet; it must differ from the other icons
    /// (task 1.2), so a neighbouring emoji id stands in until the real emoji id is supplied.
    public static let iconEcronx: Int64 = 5397879498492389616
    public static let iconXdshkaaaPlaceholder: Int64 = 5397879498492389617
    public static let defaultSubIcon: Int64 = 5402618655601109041

    public static let changedNotification = Notification.Name("MokoBadgesChanged")

    static let cacheKey = "moko.badges.cache.v2"
    static let legacyCacheKey = "moko.badges.cache.v1"
    /// https only (ATS blocks Desktop's plain-http IP mirror on iOS).
    static let apiListURL = URL(string: "https://api.moka.wtf/v1/badges")!
    static let apiEventsURL = URL(string: "https://api.moka.wtf/v1/events")!
    static let fallbackSources: [URL] = [
        URL(string: "https://raw.githubusercontent.com/ecronxy/mokagram/badges/badges.json")!
    ]
    static let minimumRefreshInterval: TimeInterval = 60
    /// The server pings every 20 s; silence for longer than this means a dead connection.
    static let eventsSilenceLimit: TimeInterval = 60
    /// With a live event stream the list is only re-read as a safety net.
    static let reconcileInterval: TimeInterval = 300
    static let signatureLimit = 64

    struct Entry: Equatable {
        var emojiId: Int64?
        var signature: String?
        var blue: Bool
    }

    struct Parsed: Equatable {
        var rev: Int64?
        var iconId: Int64?
        var blueIconId: Int64?
        var users: [Int64: Entry]
    }

    /// Console.app category `badges`. Only counts, kinds and codes go in: never user ids, signatures or URLs.
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "mokagram", category: "badges")

    private static let lock = NSLock()
    private static var loaded = false
    private static var users: [Int64: Entry] = [:]
    private static var subIcon: Int64 = defaultSubIcon
    private static var blueIcon: Int64?
    private static var rev: Int64 = 0
    private static var etag: String?
    private static var lastRefresh: Date?
    private static var inFlight = false
    private static var notifyScheduled = false

    private static func positiveId(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.int64Value > 0 {
            return number.int64Value
        }
        if let text = value as? String, let id = Int64(text), id > 0 {
            return id
        }
        return nil
    }

    private static func parseEntry(_ row: [String: Any], blueIds: Set<Int64>, userId: Int64) -> Entry {
        var signature = (row["signature"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = signature {
            signature = value.isEmpty ? nil : String(value.prefix(signatureLimit))
        }
        let blue = (row["blue"] as? Bool) ?? blueIds.contains(userId)
        return Entry(emojiId: positiveId(row["emojiId"]), signature: signature, blue: blue)
    }

    /// Parses the API list (`{"rev", "defaultEmojiId", "blueEmojiId", "blueUserIds", "badges": [...]}`) or the
    /// older `badges.json` (`{"emoji_id": "...", "users": [id, ...]}`); nil for anything that is not either shape.
    static func parse(_ data: Data) -> Parsed? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return nil
        }
        var users: [Int64: Entry] = [:]
        if let list = object["badges"] as? [Any] {
            var blueIds = Set<Int64>()
            for value in (object["blueUserIds"] as? [Any]) ?? [] {
                if let id = positiveId(value) {
                    blueIds.insert(id)
                }
            }
            for value in list {
                if let row = value as? [String: Any], let id = positiveId(row["userId"]) {
                    users[id] = parseEntry(row, blueIds: blueIds, userId: id)
                }
            }
            return Parsed(
                rev: positiveId(object["rev"]),
                iconId: positiveId(object["defaultEmojiId"]),
                blueIconId: positiveId(object["blueEmojiId"]),
                users: users
            )
        }
        guard let list = object["users"] as? [Any] else {
            return nil
        }
        for value in list {
            if let id = positiveId(value) {
                users[id] = Entry(emojiId: nil, signature: nil, blue: false)
            }
        }
        return Parsed(rev: nil, iconId: positiveId(object["emoji_id"]), blueIconId: nil, users: users)
    }

    /// The cache is stored in the API shape, so one parser reads it, the network and the legacy copy.
    private static func serialize() -> Data? {
        var rows: [[String: Any]] = []
        for (id, entry) in users {
            rows.append([
                "userId": id,
                "emojiId": entry.emojiId.map { String($0) } ?? NSNull(),
                "signature": entry.signature ?? NSNull(),
                "blue": entry.blue
            ])
        }
        var object: [String: Any] = ["rev": rev, "defaultEmojiId": String(subIcon), "badges": rows]
        if let blueIcon {
            object["blueEmojiId"] = String(blueIcon)
        }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    private static func loadIfNeeded() {
        if loaded {
            return
        }
        loaded = true
        let data = MokoStorage.defaults.data(forKey: cacheKey) ?? MokoStorage.defaults.data(forKey: legacyCacheKey)
        if let data, let parsed = parse(data) {
            users = parsed.users
            subIcon = parsed.iconId ?? defaultSubIcon
            blueIcon = parsed.blueIconId
            rev = parsed.rev ?? 0
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
            if developerUsernames.contains(username) {
                return .developer
            }
        }
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        return users[userId] != nil ? .sub : .none
    }

    /// The custom emoji to draw next to the user's name, nil when the user has no mokaGram badge.
    /// A personal icon wins over the blue one, which wins over the list's shared icon.
    public static func iconFileId(userId: Int64, username: String? = nil) -> Int64? {
        switch kind(userId: userId, username: username) {
        case .none:
            return nil
        case .developerEcronx, .developer:
            return iconEcronx
        case .developerXdshkaaa:
            return iconXdshkaaaPlaceholder
        case .sub:
            lock.lock()
            defer { lock.unlock() }
            guard let entry = users[userId] else {
                return nil
            }
            if let personal = entry.emojiId {
                return personal
            }
            if entry.blue, let blueIcon {
                return blueIcon
            }
            return subIcon
        }
    }

    /// The signature the server stores for the user, nil when there is none.
    public static func signature(userId: Int64) -> String? {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        return users[userId]?.signature
    }

    /// The text shown under the profile for a badge holder: the team role, else the server signature, else
    /// "Поддерживает mokaGram", cut to `signatureLimit`. Nil when the user has no badge.
    static func signatureText(kind: Kind, signature: String?, languageCode: String) -> String? {
        let text: String
        switch kind {
        case .none:
            return nil
        case .developerEcronx:
            text = MokoStrings.tr("Разработчик и владелец mokaGram", languageCode: languageCode)
        case .developerXdshkaaa, .developer:
            text = MokoStrings.tr("Разработчик mokaGram", languageCode: languageCode)
        case .sub:
            if let signature = signature?.trimmingCharacters(in: .whitespacesAndNewlines), !signature.isEmpty {
                text = signature
            } else {
                text = MokoStrings.tr("Поддерживает mokaGram", languageCode: languageCode)
            }
        }
        return String(text.prefix(signatureLimit))
    }

    public static func signatureText(userId: Int64, username: String? = nil, languageCode: String) -> String? {
        return signatureText(
            kind: kind(userId: userId, username: username),
            signature: signature(userId: userId),
            languageCode: languageCode
        )
    }

    /// Replaces the holder list from fetched data. Malformed data changes nothing, and so does a list older than
    /// events already applied (the server caches the list for 30 s). Returns whether the list changed.
    @discardableResult
    static func apply(_ data: Data, fromApi: Bool = false) -> Bool {
        guard let parsed = parse(data) else {
            log.error("list parse failed, bytes=\(data.count)")
            return false
        }
        lock.lock()
        loadIfNeeded()
        if let newRev = parsed.rev, newRev < rev {
            let current = rev
            lock.unlock()
            log.info("list ignored as stale, rev=\(newRev) current=\(current)")
            return false
        }
        let newIcon = parsed.iconId ?? defaultSubIcon
        let changed = users != parsed.users || subIcon != newIcon || blueIcon != parsed.blueIconId
        users = parsed.users
        subIcon = newIcon
        blueIcon = parsed.blueIconId
        rev = max(rev, parsed.rev ?? 0)
        if !fromApi {
            etag = nil
        }
        let cache = serialize()
        let count = users.count
        let currentRev = rev
        lock.unlock()
        if let cache {
            MokoStorage.defaults.set(cache, forKey: cacheKey)
        }
        log.info("list applied, source=\(fromApi ? "api" : "fallback", privacy: .public) rev=\(currentRev) count=\(count) changed=\(changed)")
        return changed
    }

    enum EventResult: Equatable {
        case ignored
        case changed
        case resync
    }

    /// One server-sent event. `badge` changes one user; `hello` asks for a full reload when the server says
    /// events were missed or its revision went backwards (a server reset).
    static func handleEvent(name: String, data: Data) -> EventResult {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .ignored
        }
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        if name == "hello" {
            let serverRev = positiveId(object["rev"]) ?? 0
            let resync = (object["resync"] as? Bool) == true
            log.info("hello, rev=\(serverRev) known=\(rev) resync=\(resync)")
            if resync {
                return .resync
            }
            if serverRev < rev {
                log.notice("server rev went backwards, reloading the list")
                rev = 0
                return .resync
            }
            return .ignored
        }
        guard name == "badge", let userId = positiveId(object["userId"]) else {
            return .ignored
        }
        var changed = false
        let type = (object["type"] as? String) ?? "unknown"
        defer {
            log.info("event, type=\(type, privacy: .public) rev=\(rev) changed=\(changed)")
        }
        if let row = object["badge"] as? [String: Any], (object["type"] as? String) != "revoked" {
            let entry = parseEntry(row, blueIds: [], userId: userId)
            changed = users[userId] != entry
            users[userId] = entry
        } else {
            changed = users.removeValue(forKey: userId) != nil
        }
        if let id = positiveId(object["id"]) {
            rev = max(rev, id)
        }
        return changed ? .changed : .ignored
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
        // Index 0 is the API, the rest are the https mirrors.
        if index > fallbackSources.count {
            // Every https source failed: ask @mokagent through the signed-in account, if the app registered one.
            lock.lock()
            let fallback = inlineFallback
            lock.unlock()
            guard let fallback else {
                log.error("list failed on every source, no bot fallback")
                finish(data: nil, fromApi: false)
                return
            }
            log.info("list request, source=bot")
            fallback { data in
                log.info("list response, source=bot received=\(data != nil)")
                finish(data: data, fromApi: false)
            }
            return
        }
        let url = index == 0 ? apiListURL : fallbackSources[index - 1]
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8.0)
        request.httpMethod = "GET"
        if index == 0 {
            lock.lock()
            let known = etag
            lock.unlock()
            if let known {
                request.setValue(known, forHTTPHeaderField: "If-None-Match")
            }
        }
        let source = index == 0 ? "api" : "github"
        log.info("list request, source=\(source, privacy: .public)")
        URLSession.shared.dataTask(with: request) { data, response, error in
            let http = response as? HTTPURLResponse
            log.info("list response, source=\(source, privacy: .public) status=\(http?.statusCode ?? 0) error=\((error as NSError?)?.code ?? 0) bytes=\(data?.count ?? 0)")
            if index == 0 && http?.statusCode == 304 {
                finish(data: nil, fromApi: true)
            } else if let data, http?.statusCode == 200, parse(data) != nil {
                if index == 0, let value = http?.value(forHTTPHeaderField: "ETag") {
                    lock.lock()
                    etag = value
                    lock.unlock()
                }
                finish(data: data, fromApi: index == 0)
            } else {
                fetch(index: index + 1)
            }
        }.resume()
    }

    private static func finish(data: Data?, fromApi: Bool) {
        var changed = false
        if let data {
            changed = apply(data, fromApi: fromApi)
        }
        lock.lock()
        inFlight = false
        lock.unlock()
        if changed {
            postChanged()
        }
    }

    private static func postChanged() {
        NotificationCenter.default.post(name: changedNotification, object: nil)
    }

    /// Events can arrive in bursts (up to 300 after a reconnect): one notification and one cache write per burst.
    private static func scheduleEventsChanged() {
        lock.lock()
        if notifyScheduled {
            lock.unlock()
            return
        }
        notifyScheduled = true
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            lock.lock()
            notifyScheduled = false
            let cache = serialize()
            lock.unlock()
            if let cache {
                MokoStorage.defaults.set(cache, forKey: cacheKey)
            }
            postChanged()
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

    // MARK: Live updates (SSE)

    private static var liveTask: Task<Void, Never>?

    /// Opens the event stream. It lives while the app is in the foreground: call `stopLiveUpdates()` on
    /// backgrounding and this again (after a list refresh) on return. Safe to call repeatedly.
    public static func startLiveUpdates() {
        lock.lock()
        defer { lock.unlock() }
        if liveTask != nil {
            return
        }
        liveTask = Task.detached {
            await runLiveUpdates()
        }
    }

    public static func stopLiveUpdates() {
        lock.lock()
        let task = liveTask
        liveTask = nil
        lock.unlock()
        task?.cancel()
    }

    private final class Silence: @unchecked Sendable {
        private let lock = NSLock()
        private var last = Date()
        func touch() {
            lock.lock()
            last = Date()
            lock.unlock()
        }
        var interval: TimeInterval {
            lock.lock()
            defer { lock.unlock() }
            return Date().timeIntervalSince(last)
        }
    }

    private static func runLiveUpdates() async {
        var failures = 0
        while !Task.isCancelled {
            let silence = Silence()
            let received = await withTaskGroup(of: Bool.self) { group -> Bool in
                group.addTask {
                    return await connectOnce(silence: silence)
                }
                group.addTask {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        if silence.interval > eventsSilenceLimit {
                            log.notice("stream silent for over \(Int(eventsSilenceLimit))s, reconnecting")
                            return false
                        }
                    }
                    return false
                }
                group.addTask {
                    // Never finishes on its own, so it cannot end the round; cancelAll stops it.
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: UInt64(reconcileInterval * 1_000_000_000))
                        if !Task.isCancelled {
                            refresh(force: true)
                        }
                    }
                    return false
                }
                // The first of the connection ending or going silent ends the round.
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }
            if Task.isCancelled {
                return
            }
            failures = received ? 1 : min(failures + 1, 10)
            let pause = min(3.0 * Double(failures), 30.0)
            log.info("stream closed, received=\(received) failures=\(failures) pause=\(pause)s")
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
        }
    }

    private static func currentRev() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()
        return rev
    }

    /// Returns whether any data arrived on this connection.
    private static func connectOnce(silence: Silence) async -> Bool {
        var request = URLRequest(url: apiEventsURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30.0)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        let lastId = currentRev()
        if lastId > 0 {
            request.setValue(String(lastId), forHTTPHeaderField: "Last-Event-ID")
        }
        var parser = EventStreamParser()
        var gotData = false
        log.info("stream connecting, lastEventId=\(lastId)")
        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                log.error("stream refused, status=\(status)")
                return false
            }
            log.info("stream connected")
            silence.touch()
            for try await byte in bytes {
                silence.touch()
                gotData = true
                guard let event = parser.feed(byte) else {
                    continue
                }
                switch handleEvent(name: event.name, data: event.data) {
                case .ignored:
                    break
                case .changed:
                    scheduleEventsChanged()
                case .resync:
                    refresh(force: true)
                }
            }
            log.info("stream ended by the server")
        } catch {
            if Task.isCancelled {
                log.info("stream cancelled")
            } else {
                let code = (error as NSError).code
                log.error("stream failed, code=\(code)")
            }
        }
        return gotData
    }

    static func _resetForTesting() {
        lock.lock()
        loaded = false
        users = [:]
        subIcon = defaultSubIcon
        blueIcon = nil
        rev = 0
        etag = nil
        lastRefresh = nil
        inFlight = false
        lock.unlock()
    }
}

/// Server-sent events, one byte at a time: a blank line ends an event, `:` lines (pings) are skipped.
struct EventStreamParser {
    struct Event: Equatable {
        var name: String
        var data: Data
    }

    private var line: [UInt8] = []
    private var name = ""
    private var data = Data()
    private var hasData = false

    mutating func feed(_ byte: UInt8) -> Event? {
        if byte == 0x0D {
            return nil
        }
        if byte != 0x0A {
            line.append(byte)
            return nil
        }
        defer { line.removeAll(keepingCapacity: true) }
        if line.isEmpty {
            defer {
                name = ""
                data = Data()
                hasData = false
            }
            return hasData || !name.isEmpty ? Event(name: name.isEmpty ? "message" : name, data: data) : nil
        }
        guard line[0] != 0x3A, let text = String(bytes: line, encoding: .utf8) else {
            return nil
        }
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        var value = parts.count > 1 ? String(parts[1]) : ""
        if value.hasPrefix(" ") {
            value.removeFirst()
        }
        switch parts[0] {
        case "event":
            name = value
        case "data":
            if hasData {
                data.append(0x0A)
            }
            data.append(Data(value.utf8))
            hasData = true
        default:
            break
        }
        return nil
    }
}
