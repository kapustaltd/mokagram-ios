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

    public static func load(accountId: Int64) -> MokoGhostSchedule {
        return MokoGhostSchedule(
            isEnabled: MokoSettings.bool("ghost.schedule", accountId: accountId),
            from: parseTime(MokoSettings.string("ghost.schedule_from", accountId: accountId)),
            to: parseTime(MokoSettings.string("ghost.schedule_to", accountId: accountId)),
            read: MokoSettings.bool("ghost.sched_read", accountId: accountId),
            online: MokoSettings.bool("ghost.sched_online", accountId: accountId),
            typing: MokoSettings.bool("ghost.sched_typing", accountId: accountId),
            stories: MokoSettings.bool("ghost.sched_stories", accountId: accountId)
        )
    }

    public static func save(_ schedule: MokoGhostSchedule, accountId: Int64) {
        MokoSettings.set(.bool(schedule.isEnabled), for: "ghost.schedule", accountId: accountId)
        MokoSettings.set(.string(formatTime(schedule.from)), for: "ghost.schedule_from", accountId: accountId)
        MokoSettings.set(.string(formatTime(schedule.to)), for: "ghost.schedule_to", accountId: accountId)
        MokoSettings.set(.bool(schedule.read), for: "ghost.sched_read", accountId: accountId)
        MokoSettings.set(.bool(schedule.online), for: "ghost.sched_online", accountId: accountId)
        MokoSettings.set(.bool(schedule.typing), for: "ghost.sched_typing", accountId: accountId)
        MokoSettings.set(.bool(schedule.stories), for: "ghost.sched_stories", accountId: accountId)
    }
}
