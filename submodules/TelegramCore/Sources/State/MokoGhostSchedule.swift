import Foundation

public struct MokoGhostFlags: Equatable {
    public var read: Bool
    public var online: Bool
    public var typing: Bool
    public var stories: Bool

    public init(read: Bool, online: Bool, typing: Bool, stories: Bool) {
        self.read = read
        self.online = online
        self.typing = typing
        self.stories = stories
    }
}

/// A daily time window during which the chosen privacy controls are added on top of the always-on ones.
/// A window whose end is before its start runs overnight; equal or unparsable ends never apply.
public struct MokoGhostSchedule: Equatable {
    public var isEnabled: Bool
    public var from: Int?
    public var to: Int?
    public var read: Bool
    public var online: Bool
    public var typing: Bool
    public var stories: Bool

    public init(isEnabled: Bool, from: Int?, to: Int?, read: Bool, online: Bool, typing: Bool, stories: Bool) {
        self.isEnabled = isEnabled
        self.from = from
        self.to = to
        self.read = read
        self.online = online
        self.typing = typing
        self.stories = stories
    }

    /// "HH:mm" -> minutes since midnight.
    public static func parseTime(_ string: String) -> Int? {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]), (0..<24).contains(hours), (0..<60).contains(minutes) else {
            return nil
        }
        return hours * 60 + minutes
    }

    public static func formatTime(_ minuteOfDay: Int?) -> String {
        guard let minuteOfDay else {
            return ""
        }
        return String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    public static func minuteOfDay(_ date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    public func contains(minuteOfDay minute: Int) -> Bool {
        guard isEnabled, let from = self.from, let to = self.to, from != to else {
            return false
        }
        return from < to ? (minute >= from && minute < to) : (minute >= from || minute < to)
    }

    public func apply(to base: MokoGhostFlags, minuteOfDay minute: Int) -> MokoGhostFlags {
        guard contains(minuteOfDay: minute) else {
            return base
        }
        return MokoGhostFlags(read: base.read || read, online: base.online || online, typing: base.typing || typing, stories: base.stories || stories)
    }

    private static func key(_ name: String, accountId: Int64) -> String {
        return "mokoGram.ghostSchedule.\(name).\(accountId)"
    }

    public static func load(accountId: Int64, defaults: UserDefaults = .standard) -> MokoGhostSchedule {
        return MokoGhostSchedule(
            isEnabled: defaults.bool(forKey: key("enabled", accountId: accountId)),
            from: defaults.string(forKey: key("from", accountId: accountId)).flatMap(parseTime) ?? parseTime("23:00"),
            to: defaults.string(forKey: key("to", accountId: accountId)).flatMap(parseTime) ?? parseTime("07:00"),
            read: defaults.bool(forKey: key("read", accountId: accountId)),
            online: defaults.bool(forKey: key("online", accountId: accountId)),
            typing: defaults.bool(forKey: key("typing", accountId: accountId)),
            stories: defaults.bool(forKey: key("stories", accountId: accountId))
        )
    }

    public static func save(_ schedule: MokoGhostSchedule, accountId: Int64, defaults: UserDefaults = .standard) {
        defaults.set(schedule.isEnabled, forKey: key("enabled", accountId: accountId))
        defaults.set(formatTime(schedule.from), forKey: key("from", accountId: accountId))
        defaults.set(formatTime(schedule.to), forKey: key("to", accountId: accountId))
        defaults.set(schedule.read, forKey: key("read", accountId: accountId))
        defaults.set(schedule.online, forKey: key("online", accountId: accountId))
        defaults.set(schedule.typing, forKey: key("typing", accountId: accountId))
        defaults.set(schedule.stories, forKey: key("stories", accountId: accountId))
    }
}
