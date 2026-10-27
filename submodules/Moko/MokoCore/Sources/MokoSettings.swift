import Foundation
import SwiftSignalKit

public enum MokoSettingScope: Equatable {
    case account
    case device
}

/// Pages of the mokaGram settings screen, in display order.
public enum MokoSettingPage: String, CaseIterable {
    case privacy
    case security
    case history
    case chats
    case music
    case tools
    case system
}

public enum MokoSettingKind: Equatable {
    case bool
    case int(min: Int, max: Int)
    /// Russian captions; the stored value is the index.
    case choice([String])
    case string
    /// "#rrggbb"
    case color
    /// A button row; nothing is stored.
    case action
}

public enum MokoSettingValue: Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)
}

/// One setting, keyed exactly as on Desktop (`ghost.read`, `commands.enabled`, `plugin.<id>.<key>`).
public struct MokoSettingEntry {
    public var key: String
    public var page: MokoSettingPage
    /// Russian group title.
    public var section: String
    /// Russian row text.
    public var title: String
    public var description: String
    public var kind: MokoSettingKind
    public var defaultValue: MokoSettingValue
    public var scope: MokoSettingScope
    /// A Bool key; while it is false the row is inactive.
    public var dependsOn: String?
    public var requiresRestart: Bool
    public var hidden: Bool

    public init(key: String, page: MokoSettingPage, section: String, title: String, description: String, kind: MokoSettingKind, defaultValue: MokoSettingValue, scope: MokoSettingScope, dependsOn: String? = nil, requiresRestart: Bool = false, hidden: Bool = false) {
        self.key = key
        self.page = page
        self.section = section
        self.title = title
        self.description = description
        self.kind = kind
        self.defaultValue = defaultValue
        self.scope = scope
        self.dependsOn = dependsOn
        self.requiresRestart = requiresRestart
        self.hidden = hidden
    }
}

/// The single registry of mokaGram settings. Only values that differ from the default are stored.
public enum MokoSettings {
    public static let didChange = Notification.Name("mokoGram.settingDidChange")

    private static let lock = NSLock()
    private static var registered: [MokoSettingEntry] = []
    private static var indices: [String: Int] = [:]
    private static var builtinsLoaded = false

    /// Values imported from a .mokaset for keys nobody had registered yet, per account:
    /// `mokoGram.s.unknown.<accountId>.<key>` holding the JSON-encoded value.
    static let unknownPrefix = "mokoGram.s.unknown."

    static func unknownStorageKey(_ key: String, accountId: Int64) -> String {
        return "\(unknownPrefix)\(accountId).\(key)"
    }

    /// (accountId, key, JSON text) of every stored unknown value.
    static func unknownValues() -> [(accountId: Int64, key: String, storageKey: String, json: String)] {
        var result: [(Int64, String, String, String)] = []
        for (storageKey, raw) in MokoStorage.defaults.dictionaryRepresentation() where storageKey.hasPrefix(unknownPrefix) {
            let rest = storageKey.dropFirst(unknownPrefix.count)
            guard let dot = rest.firstIndex(of: "."), let accountId = Int64(rest[..<dot]), let json = raw as? String else {
                continue
            }
            result.append((accountId, String(rest[rest.index(after: dot)...]), storageKey, json))
        }
        return result
    }

    /// Lock must not be held: applies imported values of keys that have just been registered.
    private static func adoptUnknownValues(for entries: [MokoSettingEntry]) {
        let byKey = Dictionary(entries.map { ($0.key, $0) }, uniquingKeysWith: { _, last in last })
        let defaults = MokoStorage.defaults
        for unknown in unknownValues() {
            guard let entry = byKey[unknown.key] else {
                continue
            }
            defaults.removeObject(forKey: unknown.storageKey)
            guard let data = unknown.json.data(using: .utf8), let raw = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]), let value = MokoSettingsFile.decode(raw, for: entry), value != entry.defaultValue else {
                continue
            }
            let target = storageKey(entry, accountId: unknown.accountId)
            switch value {
            case let .bool(raw):
                defaults.set(raw, forKey: target)
            case let .int(raw):
                defaults.set(raw, forKey: target)
            case let .string(raw):
                defaults.set(raw, forKey: target)
            }
        }
    }

    private static func ensureBuiltins() {
        lock.lock()
        let needsLoad = !builtinsLoaded
        if needsLoad {
            builtinsLoaded = true
            for entry in MokoBuiltinSettings.entries {
                insert(entry)
            }
        }
        lock.unlock()
        if needsLoad {
            adoptUnknownValues(for: MokoBuiltinSettings.entries)
        }
    }

    private static func insert(_ entry: MokoSettingEntry) {
        if let index = indices[entry.key] {
            registered[index] = entry
        } else {
            indices[entry.key] = registered.count
            registered.append(entry)
        }
    }

    static func _resetRegistryForTesting() {
        lock.lock()
        registered = []
        indices = [:]
        builtinsLoaded = false
        lock.unlock()
    }

    /// Registering the same key again replaces the entry.
    public static func register(_ entries: [MokoSettingEntry]) {
        ensureBuiltins()
        lock.lock()
        for entry in entries {
            insert(entry)
        }
        lock.unlock()
        adoptUnknownValues(for: entries)
    }

    public static func entries() -> [MokoSettingEntry] {
        ensureBuiltins()
        lock.lock()
        defer { lock.unlock() }
        return registered
    }

    public static func entry(_ key: String) -> MokoSettingEntry? {
        ensureBuiltins()
        lock.lock()
        defer { lock.unlock() }
        return indices[key].flatMap { registered[$0] }
    }

    static func storageKey(_ entry: MokoSettingEntry, accountId: Int64) -> String {
        switch entry.scope {
        case .account:
            return "mokoGram.s.\(accountId).\(entry.key)"
        case .device:
            return "mokoGram.s.device.\(entry.key)"
        }
    }

    public static func value(_ key: String, accountId: Int64) -> MokoSettingValue? {
        guard let entry = entry(key) else {
            return nil
        }
        let stored = MokoStorage.defaults.object(forKey: storageKey(entry, accountId: accountId))
        switch entry.defaultValue {
        case .bool:
            return (stored as? Bool).flatMap { .bool($0) } ?? entry.defaultValue
        case .int:
            return (stored as? Int).flatMap { .int($0) } ?? entry.defaultValue
        case .string:
            return (stored as? String).flatMap { .string($0) } ?? entry.defaultValue
        }
    }

    public static func bool(_ key: String, accountId: Int64) -> Bool {
        if case let .bool(value)? = value(key, accountId: accountId) {
            return value
        }
        return false
    }

    public static func int(_ key: String, accountId: Int64) -> Int {
        if case let .int(value)? = value(key, accountId: accountId) {
            return value
        }
        return 0
    }

    public static func string(_ key: String, accountId: Int64) -> String {
        if case let .string(value)? = value(key, accountId: accountId) {
            return value
        }
        return ""
    }

    /// Normalizes a value for an entry: nil when the type does not match, clamped for ranges.
    static func normalized(_ value: MokoSettingValue, for entry: MokoSettingEntry) -> MokoSettingValue? {
        switch (entry.defaultValue, value) {
        case (.bool, .bool), (.string, .string):
            return value
        case let (.int, .int(raw)):
            switch entry.kind {
            case let .int(minValue, maxValue):
                return .int(min(max(raw, minValue), maxValue))
            case let .choice(captions):
                return (raw >= 0 && raw < captions.count) ? value : nil
            default:
                return value
            }
        default:
            return nil
        }
    }

    public static func set(_ value: MokoSettingValue, for key: String, accountId: Int64) {
        guard let entry = entry(key), let value = normalized(value, for: entry) else {
            return
        }
        let storageKey = storageKey(entry, accountId: accountId)
        let defaults = MokoStorage.defaults
        if value == entry.defaultValue {
            defaults.removeObject(forKey: storageKey)
        } else {
            switch value {
            case let .bool(raw):
                defaults.set(raw, forKey: storageKey)
            case let .int(raw):
                defaults.set(raw, forKey: storageKey)
            case let .string(raw):
                defaults.set(raw, forKey: storageKey)
            }
        }
        postChange(entry, accountId: accountId)
    }

    private static func postChange(_ entry: MokoSettingEntry, accountId: Int64) {
        var userInfo: [String: Any] = ["key": entry.key]
        if entry.scope == .account {
            userInfo["accountId"] = accountId
        }
        NotificationCenter.default.post(name: didChange, object: nil, userInfo: userInfo)
    }

    public static func reset(_ key: String, accountId: Int64) {
        guard let entry = entry(key) else {
            return
        }
        MokoStorage.defaults.removeObject(forKey: storageKey(entry, accountId: accountId))
        postChange(entry, accountId: accountId)
    }

    public static func reset(page: MokoSettingPage, accountId: Int64) {
        for entry in entries() where entry.page == page {
            reset(entry.key, accountId: accountId)
        }
    }

    /// Also drops this account's imported values for keys nobody has registered.
    public static func resetAll(accountId: Int64) {
        for entry in entries() {
            reset(entry.key, accountId: accountId)
        }
        for unknown in unknownValues() where unknown.accountId == accountId {
            MokoStorage.defaults.removeObject(forKey: unknown.storageKey)
        }
    }

    public static func isChanged(_ key: String, accountId: Int64) -> Bool {
        guard let entry = entry(key) else {
            return false
        }
        return MokoStorage.defaults.object(forKey: storageKey(entry, accountId: accountId)) != nil
    }

    /// The current value, then every change of it for this account.
    public static func boolSignal(_ key: String, accountId: Int64) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            subscriber.putNext(bool(key, accountId: accountId))
            let observer = NotificationCenter.default.addObserver(forName: didChange, object: nil, queue: nil, using: { notification in
                guard notification.userInfo?["key"] as? String == key else {
                    return
                }
                if let changedAccountId = notification.userInfo?["accountId"] as? Int64, changedAccountId != accountId {
                    return
                }
                subscriber.putNext(bool(key, accountId: accountId))
            })
            return ActionDisposable {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        |> distinctUntilChanged
    }
}
