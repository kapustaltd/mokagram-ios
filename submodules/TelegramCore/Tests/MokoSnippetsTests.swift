import Foundation
import XCTest
@testable import TelegramCore

final class MokoSnippetsTests: XCTestCase {
    func testExpansionPreservesOtherAttributesAndAccountIsolation() {
        let suite = "MokoSnippetsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(MokoSnippets.save(name: "Привет", text: "Здравствуй", accountId: 1, defaults: defaults))
        XCTAssertFalse(MokoSnippets.save(name: "invalid name", text: "x", accountId: 1, defaults: defaults))
        let key = NSAttributedString.Key("test")
        let source = NSMutableAttributedString(string: "😀 ;ПРИВЕТ and ;unknown")
        source.addAttribute(key, value: "keep", range: NSRange(location: 0, length: 2))
        let result = MokoSnippets.expand(source, accountId: 1, defaults: defaults)
        XCTAssertEqual(result.string, "😀 Здравствуй and ;unknown")
        XCTAssertEqual(result.attribute(key, at: 0, effectiveRange: nil) as? String, "keep")
        XCTAssertEqual(MokoSnippets.expand(source, accountId: 2, defaults: defaults).string, source.string)
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: "x;привет ;привет_suffix"), accountId: 1, defaults: defaults).string, "x;привет ;привет_suffix")
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: ";привет\n;ПРИВЕТ"), accountId: 1, defaults: defaults).string, "Здравствуй\nЗдравствуй")
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: ";привет1234567890123456789012345"), accountId: 1, defaults: defaults).string, ";привет1234567890123456789012345")
        XCTAssertTrue(MokoSnippets.save(name: "привет", text: "", accountId: 1, defaults: defaults))
        XCTAssertTrue(MokoSnippets.all(accountId: 1, defaults: defaults).isEmpty)
    }
}
