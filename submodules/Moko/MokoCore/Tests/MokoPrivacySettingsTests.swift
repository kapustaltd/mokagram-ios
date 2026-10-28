import Foundation
import XCTest
import MokoCore

final class MokoPrivacySettingsTests: XCTestCase {
    func testAccountSettingsAreIndependent() {
        let suite = "MokoPrivacySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1))
        MokoPrivacySettings.setSuppressOnlineUpdates(true, accountId: 1)
        XCTAssertTrue(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 2))
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1))
        MokoPrivacySettings.setSuppressAutomaticRead(true, accountId: 1)
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 2))
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 3))
        MokoPrivacySettings.setAllowsAutomaticRead(true, accountId: 1, peerId: 3)
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 3))
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 4))
        XCTAssertFalse(MokoPrivacySettings.allowsAutomaticRead(accountId: 2, peerId: 3))
        MokoPrivacySettings.setHideTyping(true, accountId: 1)
        XCTAssertTrue(MokoPrivacySettings.hideTyping(accountId: 1))
        XCTAssertTrue(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 2))
        MokoPrivacySettings.setHideTyping(false, accountId: 1)
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.hideStoryViews(accountId: 1))
        MokoPrivacySettings.setHideStoryViews(true, accountId: 1)
        XCTAssertTrue(MokoPrivacySettings.hideStoryViews(accountId: 1))
        XCTAssertFalse(MokoPrivacySettings.hideStoryViews(accountId: 2))
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1))
    }

    func testGhostMasterGatesFlags() {
        let suite = "MokoPrivacySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }
        // Desktop defaults: every flag is on, the master switch is off.
        XCTAssertEqual(MokoPrivacySettings.storedFlags(accountId: 1), MokoGhostFlags(read: false, online: false, typing: false, stories: false))
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        XCTAssertEqual(MokoPrivacySettings.storedFlags(accountId: 1), MokoGhostFlags(read: true, online: true, typing: true, stories: true))
        MokoSettings.set(.bool(false), for: "ghost.typing", accountId: 1)
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1, minuteOfDay: 12 * 60))
    }

    func testDesktopImportWithGhostOffSuppressesNothing() {
        let suite = "MokoPrivacySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }
        _ = MokoSettingsFile.apply("{\"format\":\"mokaset\",\"version\":1,\"values\":{\"ghost.read\":true}}".data(using: .utf8)!, accountId: 1)
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 5, minuteOfDay: 12 * 60))
    }
}
