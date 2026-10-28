import Foundation
import XCTest
@testable import TelegramCore

final class MokoActivityFilterTests: XCTestCase {
    func testActivityFiltering() {
        XCTAssertTrue(mokoShouldSendActivity(.typingText, hideTyping: false))
        XCTAssertFalse(mokoShouldSendActivity(.typingText, hideTyping: true))
        XCTAssertFalse(mokoShouldSendActivity(.recordingVoice, hideTyping: true))
        XCTAssertFalse(mokoShouldSendActivity(.uploadingFile(progress: 50), hideTyping: true))
        XCTAssertTrue(mokoShouldSendActivity(.speakingInGroupCall(timestamp: 0), hideTyping: true))
        XCTAssertTrue(mokoShouldSendActivity(nil, hideTyping: true))
    }
}
