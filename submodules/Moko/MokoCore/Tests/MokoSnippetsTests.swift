import Foundation
import XCTest
import MokoCore

final class MokoSnippetsTests: XCTestCase {
    func testExpansionPreservesOtherAttributesAndAccountIsolation() {
        let suite = "MokoSnippetsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertTrue(MokoSnippets.save(name: "Привет", text: "Здравствуй", accountId: 1))
        XCTAssertFalse(MokoSnippets.save(name: "invalid name", text: "x", accountId: 1))
        let key = NSAttributedString.Key("test")
        let source = NSMutableAttributedString(string: "😀 ;ПРИВЕТ and ;unknown")
        source.addAttribute(key, value: "keep", range: NSRange(location: 0, length: 2))
        let result = MokoSnippets.expand(source, accountId: 1)
        XCTAssertEqual(result.string, "😀 Здравствуй and ;unknown")
        XCTAssertEqual(result.attribute(key, at: 0, effectiveRange: nil) as? String, "keep")
        XCTAssertEqual(MokoSnippets.expand(source, accountId: 2).string, source.string)
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: "x;привет ;привет_suffix"), accountId: 1).string, "x;привет ;привет_suffix")
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: ";привет\n;ПРИВЕТ"), accountId: 1).string, "Здравствуй\nЗдравствуй")
        XCTAssertEqual(MokoSnippets.expand(NSAttributedString(string: ";привет1234567890123456789012345"), accountId: 1).string, ";привет1234567890123456789012345")
        XCTAssertTrue(MokoSnippets.save(name: "привет", text: "", accountId: 1))
        XCTAssertTrue(MokoSnippets.all(accountId: 1).isEmpty)
    }
}
