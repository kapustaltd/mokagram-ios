import Foundation

/// Device-local privacy controls for a single Telegram account ("Призрак" on Desktop).
/// A control is active when the master switch `ghost.enabled` and its own key are both on,
/// or when the schedule adds it.
public enum MokoPrivacySettings {
    private static let flagKeys = ["ghost.read", "ghost.online", "ghost.typing", "ghost.stories"]

    /// What the user switched on, ignoring the schedule. Settings screens show and edit these.
    public static func storedFlags(accountId: Int64) -> MokoGhostFlags {
        guard MokoSettings.bool("ghost.enabled", accountId: accountId) else {
            return MokoGhostFlags(read: false, online: false, typing: false, stories: false)
        }
        return MokoGhostFlags(
            read: MokoSettings.bool("ghost.read", accountId: accountId),
            online: MokoSettings.bool("ghost.online", accountId: accountId),
            typing: MokoSettings.bool("ghost.typing", accountId: accountId),
            stories: MokoSettings.bool("ghost.stories", accountId: accountId)
        )
    }

    private static func scheduledFlags(accountId: Int64, minuteOfDay: Int) -> MokoGhostFlags {
        return MokoGhostSchedule.load(accountId: accountId).apply(to: storedFlags(accountId: accountId), minuteOfDay: minuteOfDay)
    }

    /// Turns one control on or off without switching the others: turning the first one on enables
    /// the master switch with every other control off, turning the last one off disables it.
    private static func setFlag(_ key: String, _ value: Bool, accountId: Int64) {
        let enabled = MokoSettings.bool("ghost.enabled", accountId: accountId)
        if value {
            if !enabled {
                for other in flagKeys where other != key {
                    MokoSettings.set(.bool(false), for: other, accountId: accountId)
                }
                MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: accountId)
            }
            MokoSettings.set(.bool(true), for: key, accountId: accountId)
        } else if enabled {
            MokoSettings.set(.bool(false), for: key, accountId: accountId)
            if !flagKeys.contains(where: { MokoSettings.bool($0, accountId: accountId) }) {
                MokoSettings.set(.bool(false), for: "ghost.enabled", accountId: accountId)
                for flag in flagKeys {
                    MokoSettings.reset(flag, accountId: accountId)
                }
            }
        }
    }

    public static func hideTyping(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date())) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay).typing
    }

    public static func setHideTyping(_ value: Bool, accountId: Int64) {
        setFlag("ghost.typing", value, accountId: accountId)
    }

    public static func hideStoryViews(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date())) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay).stories
    }

    public static func setHideStoryViews(_ value: Bool, accountId: Int64) {
        setFlag("ghost.stories", value, accountId: accountId)
    }

    public static func suppressOnlineUpdates(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date())) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay).online
    }

    public static func setSuppressOnlineUpdates(_ value: Bool, accountId: Int64) {
        setFlag("ghost.online", value, accountId: accountId)
    }

    public static func suppressAutomaticRead(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date())) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay).read
    }

    public static func setSuppressAutomaticRead(_ value: Bool, accountId: Int64) {
        setFlag("ghost.read", value, accountId: accountId)
    }

    static func automaticReadExceptionKey(accountId: Int64, peerId: Int64) -> String {
        return "mokoGram.automaticReadException.\(accountId).\(peerId)"
    }

    public static func allowsAutomaticRead(accountId: Int64, peerId: Int64) -> Bool {
        return MokoStorage.defaults.bool(forKey: automaticReadExceptionKey(accountId: accountId, peerId: peerId))
    }

    public static func setAllowsAutomaticRead(_ value: Bool, accountId: Int64, peerId: Int64) {
        let key = automaticReadExceptionKey(accountId: accountId, peerId: peerId)
        if value {
            MokoStorage.defaults.set(true, forKey: key)
        } else {
            MokoStorage.defaults.removeObject(forKey: key)
        }
    }

    public static func suppressAutomaticRead(accountId: Int64, peerId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date())) -> Bool {
        return suppressAutomaticRead(accountId: accountId, minuteOfDay: minuteOfDay) && !allowsAutomaticRead(accountId: accountId, peerId: peerId)
    }
}
