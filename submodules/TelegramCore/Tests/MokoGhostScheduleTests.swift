import Foundation
import XCTest
@testable import TelegramCore

final class MokoGhostScheduleTests: XCTestCase {
    private func schedule(_ from: String, _ to: String, enabled: Bool = true) -> MokoGhostSchedule {
        return MokoGhostSchedule(isEnabled: enabled, from: MokoGhostSchedule.parseTime(from), to: MokoGhostSchedule.parseTime(to), read: true, online: true, typing: false, stories: false)
    }

    func testParseTime() {
        XCTAssertEqual(MokoGhostSchedule.parseTime("07:05"), 7 * 60 + 5)
        XCTAssertEqual(MokoGhostSchedule.parseTime(" 23:00 "), 23 * 60)
        XCTAssertNil(MokoGhostSchedule.parseTime("24:00"))
        XCTAssertNil(MokoGhostSchedule.parseTime("7:60"))
        XCTAssertNil(MokoGhostSchedule.parseTime("abc"))
    }

    func testSameDayRange() {
        let s = schedule("09:00", "17:00")
        XCTAssertFalse(s.contains(minuteOfDay: 8 * 60 + 59))
        XCTAssertTrue(s.contains(minuteOfDay: 9 * 60))
        XCTAssertTrue(s.contains(minuteOfDay: 16 * 60 + 59))
        XCTAssertFalse(s.contains(minuteOfDay: 17 * 60))
    }

    func testOvernightRange() {
        let s = schedule("23:00", "07:00")
        XCTAssertTrue(s.contains(minuteOfDay: 23 * 60))
        XCTAssertTrue(s.contains(minuteOfDay: 0))
        XCTAssertTrue(s.contains(minuteOfDay: 6 * 60 + 59))
        XCTAssertFalse(s.contains(minuteOfDay: 7 * 60))
        XCTAssertFalse(s.contains(minuteOfDay: 12 * 60))
        XCTAssertFalse(s.contains(minuteOfDay: 22 * 60 + 59))
    }

    func testDegenerateSchedulesNeverApply() {
        XCTAssertFalse(schedule("08:00", "08:00").contains(minuteOfDay: 8 * 60))
        XCTAssertFalse(schedule("xx", "07:00").contains(minuteOfDay: 0))
        XCTAssertFalse(schedule("23:00", "07:00", enabled: false).contains(minuteOfDay: 0))
    }

    func testEffectiveFlagsAddScheduledOnesInsideWindow() {
        let s = schedule("23:00", "07:00")
        let base = MokoGhostFlags(read: false, online: false, typing: true, stories: false)
        let inside = s.apply(to: base, minuteOfDay: 1 * 60)
        XCTAssertEqual(inside, MokoGhostFlags(read: true, online: true, typing: true, stories: false))
        XCTAssertEqual(s.apply(to: base, minuteOfDay: 12 * 60), base)
    }

    func testMinuteOfDayUsesCalendarTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        let date = Date(timeIntervalSince1970: 22 * 3600) // 22:00 UTC == 01:00 at +03:00
        XCTAssertEqual(MokoGhostSchedule.minuteOfDay(date, calendar: calendar), 60)
    }

    func testPersistenceIsPerAccount() {
        let suite = "MokoGhostScheduleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(MokoGhostSchedule.load(accountId: 1, defaults: defaults).isEnabled)
        MokoGhostSchedule.save(schedule("22:30", "06:15"), accountId: 1, defaults: defaults)
        let loaded = MokoGhostSchedule.load(accountId: 1, defaults: defaults)
        XCTAssertTrue(loaded.isEnabled)
        XCTAssertEqual(loaded.from, 22 * 60 + 30)
        XCTAssertEqual(loaded.to, 6 * 60 + 15)
        XCTAssertTrue(loaded.read)
        XCTAssertFalse(MokoGhostSchedule.load(accountId: 2, defaults: defaults).isEnabled)
    }

    func testPrivacyGettersHonourSchedule() {
        let suite = "MokoGhostScheduleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        MokoGhostSchedule.save(schedule("23:00", "07:00"), accountId: 1, defaults: defaults)
        XCTAssertTrue(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1, minuteOfDay: 60, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1, minuteOfDay: 12 * 60, defaults: defaults))
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 5, minuteOfDay: 60, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 5, minuteOfDay: 12 * 60, defaults: defaults))
        MokoPrivacySettings.setAllowsAutomaticRead(true, accountId: 1, peerId: 5, defaults: defaults)
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 5, minuteOfDay: 60, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1, minuteOfDay: 60, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 2, minuteOfDay: 60, defaults: defaults))
    }
}
