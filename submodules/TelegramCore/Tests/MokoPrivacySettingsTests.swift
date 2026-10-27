import Foundation
import XCTest
@testable import TelegramCore

final class MokoPrivacySettingsTests: XCTestCase {
    func testActivityFiltering() {
        XCTAssertTrue(mokoShouldSendActivity(.typingText, hideTyping: false))
        XCTAssertFalse(mokoShouldSendActivity(.typingText, hideTyping: true))
        XCTAssertFalse(mokoShouldSendActivity(.recordingVoice, hideTyping: true))
        XCTAssertFalse(mokoShouldSendActivity(.uploadingFile(progress: 50), hideTyping: true))
        XCTAssertTrue(mokoShouldSendActivity(.speakingInGroupCall(timestamp: 0), hideTyping: true))
        XCTAssertTrue(mokoShouldSendActivity(nil, hideTyping: true))
    }

    func testAccountSettingsAreIndependent() {
        let suite = "MokoPrivacySettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1, defaults: defaults))
        MokoPrivacySettings.setSuppressOnlineUpdates(true, accountId: 1, defaults: defaults)
        XCTAssertTrue(MokoPrivacySettings.suppressOnlineUpdates(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressOnlineUpdates(accountId: 2, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, defaults: defaults))
        MokoPrivacySettings.setSuppressAutomaticRead(true, accountId: 1, defaults: defaults)
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 2, defaults: defaults))
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 3, defaults: defaults))
        MokoPrivacySettings.setAllowsAutomaticRead(true, accountId: 1, peerId: 3, defaults: defaults)
        XCTAssertFalse(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 3, defaults: defaults))
        XCTAssertTrue(MokoPrivacySettings.suppressAutomaticRead(accountId: 1, peerId: 4, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.allowsAutomaticRead(accountId: 2, peerId: 3, defaults: defaults))
        MokoPrivacySettings.setHideTyping(true, accountId: 1, defaults: defaults)
        XCTAssertTrue(MokoPrivacySettings.hideTyping(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 2, defaults: defaults))
        MokoPrivacySettings.setHideTyping(false, accountId: 1, defaults: defaults)
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.hideStoryViews(accountId: 1, defaults: defaults))
        MokoPrivacySettings.setHideStoryViews(true, accountId: 1, defaults: defaults)
        XCTAssertTrue(MokoPrivacySettings.hideStoryViews(accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.hideStoryViews(accountId: 2, defaults: defaults))
        XCTAssertFalse(MokoPrivacySettings.hideTyping(accountId: 1, defaults: defaults))
    }
}
