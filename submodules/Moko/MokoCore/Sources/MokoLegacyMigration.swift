import Foundation

/// One-time move of what earlier iOS builds stored in the app's own defaults: settings become
/// registry keys, data keys (notes, snippets, read exceptions) move to the app group unchanged.
public enum MokoLegacyMigration {
    private static let doneKey = "mokoGram.migrated.v1"

    private static let flags: [(legacy: String, key: String)] = [
        ("mokoGram.hideTyping.", "ghost.typing"),
        ("mokoGram.hideStoryViews.", "ghost.stories"),
        ("mokoGram.suppressOnlineUpdates.", "ghost.online"),
        ("mokoGram.suppressAutomaticRead.", "ghost.read"),
    ]

    private static let schedule: [(legacy: String, key: String)] = [
        ("enabled", "ghost.schedule"),
        ("from", "ghost.schedule_from"),
        ("to", "ghost.schedule_to"),
        ("read", "ghost.sched_read"),
        ("online", "ghost.sched_online"),
        ("typing", "ghost.sched_typing"),
        ("stories", "ghost.sched_stories"),
    ]

    private static let dataPrefixes = ["mokoGram.snippets.", "mokoGram.peerNote.", "mokoGram.automaticReadException."]

    private static func accountId(_ key: String, prefix: String) -> Int64? {
        guard key.hasPrefix(prefix) else {
            return nil
        }
        return Int64(key.dropFirst(prefix.count))
    }

    public static func run(legacy: UserDefaults) {
        let target = MokoStorage.defaults
        guard !target.bool(forKey: doneKey) else {
            return
        }
        let values = legacy.dictionaryRepresentation().filter { $0.key.hasPrefix("mokoGram.") }
        var moved: [String] = []

        var accountFlags: [Int64: [String: Bool]] = [:]
        for (key, value) in values {
            for flag in flags {
                if let account = accountId(key, prefix: flag.legacy), let value = value as? Bool {
                    accountFlags[account, default: [:]][flag.key] = value
                    moved.append(key)
                }
            }
        }
        for (account, set) in accountFlags where set.values.contains(true) {
            MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: account)
            for flag in flags {
                MokoSettings.set(.bool(set[flag.key] ?? false), for: flag.key, accountId: account)
            }
        }

        for (key, value) in values {
            for item in schedule {
                guard let account = accountId(key, prefix: "mokoGram.ghostSchedule.\(item.legacy).") else {
                    continue
                }
                if let value = value as? Bool {
                    MokoSettings.set(.bool(value), for: item.key, accountId: account)
                } else if let value = value as? String {
                    MokoSettings.set(.string(value), for: item.key, accountId: account)
                }
                moved.append(key)
            }
            if let account = accountId(key, prefix: "mokoGram.quickCommands."), let value = value as? Bool {
                MokoSettings.set(.bool(value), for: "commands.enabled", accountId: account)
                moved.append(key)
            }
            if let account = accountId(key, prefix: "mokoGram.commandAliases."), let aliases = value as? [String: String] {
                MokoSettings.set(.string(MokoQuickCommands.formatAliases(aliases)), for: "commands.aliases", accountId: account)
                moved.append(key)
            }
            if dataPrefixes.contains(where: { key.hasPrefix($0) }) {
                target.set(value, forKey: key)
                moved.append(key)
            }
        }

        for key in moved {
            legacy.removeObject(forKey: key)
        }
        target.set(true, forKey: doneKey)
    }
}
