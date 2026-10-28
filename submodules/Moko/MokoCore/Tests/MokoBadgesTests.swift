import Foundation
import XCTest
@testable import MokoCore

final class MokoBadgesTests: XCTestCase {
    private func makeDefaults() -> () -> Void {
        let suite = "MokoBadgesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        MokoBadges._resetForTesting()
        return { defaults.removePersistentDomain(forName: suite) }
    }

    func testParseAcceptsNumbersAndStrings() {
        let parsed = MokoBadges.parse(Data(#"{"emoji_id":"123","users":[5,"6",-1,"x",true]}"#.utf8))
        XCTAssertEqual(parsed, MokoBadges.Parsed(iconId: 123, users: [5, 6]))
    }

    func testParseRejectsMalformed() {
        XCTAssertNil(MokoBadges.parse(Data("not json".utf8)))
        XCTAssertNil(MokoBadges.parse(Data(#"{"emoji_id":"1"}"#.utf8)))
        XCTAssertNil(MokoBadges.parse(Data("[1,2]".utf8)))
    }

    func testMalformedDataKeepsCache() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        XCTAssertTrue(MokoBadges.apply(Data(#"{"emoji_id":"777","users":[10,11]}"#.utf8)))
        XCTAssertFalse(MokoBadges.apply(Data("garbage".utf8)))
        XCTAssertEqual(MokoBadges.kind(userId: 10), .sub)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 11), 777)
        // A relaunch reads the cache.
        MokoBadges._resetForTesting()
        XCTAssertEqual(MokoBadges.kind(userId: 10), .sub)
        XCTAssertEqual(MokoBadges.kind(userId: 12), .none)
        XCTAssertNil(MokoBadges.iconFileId(userId: 12))
    }

    func testDevelopersWinOverListEntries() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(#"{"emoji_id":"777","users":[6612638154,42]}"#.utf8))
        XCTAssertEqual(MokoBadges.kind(userId: 6612638154), .developerEcronx)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 6612638154), MokoBadges.iconEcronx)
        XCTAssertEqual(MokoBadges.kind(userId: 42, username: "XdShkaaa"), .developerXdshkaaa)
        XCTAssertNotEqual(MokoBadges.iconFileId(userId: 42, username: "xdshkaaa"), MokoBadges.iconFileId(userId: 42))
        XCTAssertNotEqual(MokoBadges.iconEcronx, MokoBadges.iconXdshkaaaPlaceholder)
        XCTAssertEqual(MokoBadges.kind(userId: 42), .sub)
    }
}
