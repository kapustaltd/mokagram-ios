import Foundation

/// Device-local privacy controls for a single Telegram account.
public enum MokoPrivacySettings {
    static let onlineChanged = Notification.Name("mokoGram.onlinePrivacyChanged")
    private static func typingKey(accountId: Int64) -> String {
        return "mokoGram.hideTyping.\(accountId)"
    }

    /// What the user switched on, ignoring the schedule. Settings screens show and edit these.
    public static func storedFlags(accountId: Int64, defaults: UserDefaults = .standard) -> MokoGhostFlags {
        return MokoGhostFlags(
            read: defaults.bool(forKey: automaticReadKey(accountId: accountId)),
            online: defaults.bool(forKey: onlineKey(accountId: accountId)),
            typing: defaults.bool(forKey: typingKey(accountId: accountId)),
            stories: defaults.bool(forKey: storyViewsKey(accountId: accountId))
        )
    }

    private static func scheduledFlags(accountId: Int64, minuteOfDay: Int, defaults: UserDefaults) -> MokoGhostFlags {
        let base = storedFlags(accountId: accountId, defaults: defaults)
        return MokoGhostSchedule.load(accountId: accountId, defaults: defaults).apply(to: base, minuteOfDay: minuteOfDay)
    }

    public static func hideTyping(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date()), defaults: UserDefaults = .standard) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay, defaults: defaults).typing
    }

    public static func setHideTyping(_ value: Bool, accountId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: typingKey(accountId: accountId))
    }

    private static func storyViewsKey(accountId: Int64) -> String {
        return "mokoGram.hideStoryViews.\(accountId)"
    }

    public static func hideStoryViews(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date()), defaults: UserDefaults = .standard) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay, defaults: defaults).stories
    }

    public static func setHideStoryViews(_ value: Bool, accountId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: storyViewsKey(accountId: accountId))
    }

    private static func onlineKey(accountId: Int64) -> String {
        return "mokoGram.suppressOnlineUpdates.\(accountId)"
    }

    public static func suppressOnlineUpdates(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date()), defaults: UserDefaults = .standard) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay, defaults: defaults).online
    }

    public static func setSuppressOnlineUpdates(_ value: Bool, accountId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: onlineKey(accountId: accountId))
        NotificationCenter.default.post(name: onlineChanged, object: nil, userInfo: ["accountId": accountId])
    }

    private static func automaticReadKey(accountId: Int64) -> String {
        return "mokoGram.suppressAutomaticRead.\(accountId)"
    }

    public static func suppressAutomaticRead(accountId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date()), defaults: UserDefaults = .standard) -> Bool {
        return scheduledFlags(accountId: accountId, minuteOfDay: minuteOfDay, defaults: defaults).read
    }

    public static func setSuppressAutomaticRead(_ value: Bool, accountId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: automaticReadKey(accountId: accountId))
    }

    private static func automaticReadExceptionKey(accountId: Int64, peerId: Int64) -> String {
        return "mokoGram.automaticReadException.\(accountId).\(peerId)"
    }

    public static func allowsAutomaticRead(accountId: Int64, peerId: Int64, defaults: UserDefaults = .standard) -> Bool {
        return defaults.bool(forKey: automaticReadExceptionKey(accountId: accountId, peerId: peerId))
    }

    public static func setAllowsAutomaticRead(_ value: Bool, accountId: Int64, peerId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: automaticReadExceptionKey(accountId: accountId, peerId: peerId))
    }

    public static func suppressAutomaticRead(accountId: Int64, peerId: Int64, minuteOfDay: Int = MokoGhostSchedule.minuteOfDay(Date()), defaults: UserDefaults = .standard) -> Bool {
        return suppressAutomaticRead(accountId: accountId, minuteOfDay: minuteOfDay, defaults: defaults) && !allowsAutomaticRead(accountId: accountId, peerId: peerId, defaults: defaults)
    }
}
