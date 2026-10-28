import Foundation

/// Where mokaGram keeps its values: the app group shared with the extensions, so the notification
/// service sees the same settings as the app. Falls back to the given defaults when the group is
/// unavailable (host tests, an unsigned build without the entitlement).
public enum MokoStorage {
    private static let lock = NSLock()
    private static var current: UserDefaults?
    private static var groupName: String?

    /// The app group of a bundle. The re-signed build uses a group that does not follow the bundle id.
    public static func appGroupName(baseAppBundleId: String) -> String {
        return baseAppBundleId == "app.starfruit2689.orange1525" ? "group.8597cef54a2b8971.1" : "group.\(baseAppBundleId)"
    }

    public static func configure(appGroupName: String?, fallback: UserDefaults = .standard) {
        let shared = appGroupName.flatMap { UserDefaults(suiteName: $0) }
        lock.lock()
        current = shared ?? fallback
        groupName = shared != nil ? appGroupName : nil
        lock.unlock()
    }

    public static var defaults: UserDefaults {
        lock.lock()
        defer { lock.unlock() }
        return current ?? .standard
    }

    /// The app group container for files (music, deleted messages). Nil without a group.
    public static var containerURL: URL? {
        lock.lock()
        let name = groupName
        lock.unlock()
        return name.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
    }

    /// Tests only: points storage at `defaults` and restores the built-in settings registry.
    public static func _resetForTesting(defaults: UserDefaults) {
        lock.lock()
        current = defaults
        groupName = nil
        lock.unlock()
        MokoSettings._resetRegistryForTesting()
    }
}
