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
        let plain = MokoBadges.Entry(emojiId: nil, signature: nil, blue: false)
        XCTAssertEqual(parsed, MokoBadges.Parsed(rev: nil, iconId: 123, blueIconId: nil, users: [5: plain, 6: plain]))
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

    private let apiList = #"""
    {"rev":5,"defaultEmojiId":"100","blueEmojiId":"200","blueUserIds":[3],"total":4,"badges":[
    {"userId":1,"tier":3,"emojiId":"111","signature":"  Поддержка  ","blue":false,"grantedAt":1},
    {"userId":2,"tier":1,"emojiId":null,"signature":null,"blue":false,"grantedAt":2},
    {"userId":3,"tier":2,"emojiId":null,"signature":null,"blue":true,"grantedAt":3},
    {"userId":0,"emojiId":null},{"userId":"x"}]}
    """#

    func testParseApiList() {
        let parsed = MokoBadges.parse(Data(apiList.utf8))
        XCTAssertEqual(parsed?.rev, 5)
        XCTAssertEqual(parsed?.iconId, 100)
        XCTAssertEqual(parsed?.blueIconId, 200)
        XCTAssertEqual(parsed?.users.count, 3)
        XCTAssertEqual(parsed?.users[1], MokoBadges.Entry(emojiId: 111, signature: "Поддержка", blue: false))
        XCTAssertEqual(parsed?.users[3]?.blue, true)
    }

    func testIconPriorityPersonalBlueDefault() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        XCTAssertEqual(MokoBadges.iconFileId(userId: 1), 111)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 2), 100)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 3), 200)
        XCTAssertEqual(MokoBadges.signature(userId: 1), "Поддержка")
        XCTAssertNil(MokoBadges.signature(userId: 2))
    }

    func testCacheSurvivesRelaunchWithPersonalData() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        MokoBadges._resetForTesting()
        XCTAssertEqual(MokoBadges.iconFileId(userId: 1), 111)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 3), 200)
        XCTAssertEqual(MokoBadges.signature(userId: 1), "Поддержка")
    }

    func testLegacyV1CacheIsRead() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoStorage.defaults.set(Data(#"{"emoji_id":"777","users":[10]}"#.utf8), forKey: MokoBadges.legacyCacheKey)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 10), 777)
    }

    func testEventsGrantUpdateRevoke() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":6,"type":"granted","userId":50,"badge":{"emojiId":"900","signature":"s","blue":false}}"#.utf8)), .changed)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 50), 900)
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":7,"type":"updated","userId":50,"badge":{"emojiId":null,"signature":null,"blue":false}}"#.utf8)), .changed)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 50), 100)
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":8,"type":"revoked","userId":50,"badge":null}"#.utf8)), .changed)
        XCTAssertNil(MokoBadges.iconFileId(userId: 50))
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":9,"type":"revoked","userId":50,"badge":null}"#.utf8)), .ignored)
    }

    func testBrokenEventsAreSkipped() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data("nope".utf8)), .ignored)
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"type":"granted","badge":{}}"#.utf8)), .ignored)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 1), 111)
    }

    func testRevokedDeveloperKeepsPersonalIcon() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        XCTAssertEqual(MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":2,"type":"revoked","userId":6612638154,"badge":null}"#.utf8)), .ignored)
        XCTAssertEqual(MokoBadges.kind(userId: 6612638154), .developerEcronx)
    }

    func testDevelopersByUsernameGetRoleAndBlueIcon() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        for name in ["xdshka", "XdShka", "litteraliy", "LITTERALIY"] {
            XCTAssertEqual(MokoBadges.kind(userId: 42, username: name), .developer, name)
            XCTAssertEqual(MokoBadges.iconFileId(userId: 42, username: name), MokoBadges.iconEcronx, name)
        }
        XCTAssertEqual(MokoBadges.kind(userId: 42, username: "ecronx"), .developerEcronx)
        XCTAssertEqual(MokoBadges.kind(userId: 42, username: "xdshkaaa"), .developerXdshkaaa)
        XCTAssertEqual(MokoBadges.kind(userId: 42, username: "someone"), .none)
        // The owner is found by id even when the username is hidden.
        XCTAssertEqual(MokoBadges.kind(userId: 6612638154, username: nil), .developerEcronx)
    }

    func testDeveloperIconWinsOverPersonalAndServerBlue() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        // User 3 is a server-blue holder; as a developer by name the client blue wins.
        XCTAssertEqual(MokoBadges.iconFileId(userId: 3), 200)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 3, username: "litteraliy"), MokoBadges.iconEcronx)
        XCTAssertEqual(MokoBadges.iconFileId(userId: 1, username: "xdshka"), MokoBadges.iconEcronx)
    }

    func testServerBlueWithoutBlueIconFallsBackToShared() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(#"{"rev":1,"defaultEmojiId":"100","badges":[{"userId":3,"emojiId":null,"blue":true}]}"#.utf8))
        XCTAssertEqual(MokoBadges.iconFileId(userId: 3), 100)
    }

    func testSignatureTextPriorities() {
        let none = MokoBadges.signatureText(kind: .none, signature: "x", languageCode: "ru")
        XCTAssertNil(none)
        XCTAssertEqual(MokoBadges.signatureText(kind: .developerEcronx, signature: "x", languageCode: "ru"), "Разработчик и владелец mokaGram")
        XCTAssertEqual(MokoBadges.signatureText(kind: .developer, signature: "x", languageCode: "ru"), "Разработчик mokaGram")
        XCTAssertEqual(MokoBadges.signatureText(kind: .developerXdshkaaa, signature: nil, languageCode: "en"), "mokaGram developer")
        XCTAssertEqual(MokoBadges.signatureText(kind: .sub, signature: "  Поддержка  ", languageCode: "ru"), "Поддержка")
        XCTAssertEqual(MokoBadges.signatureText(kind: .sub, signature: nil, languageCode: "ru"), "Поддерживает mokaGram")
        XCTAssertEqual(MokoBadges.signatureText(kind: .sub, signature: "   ", languageCode: "ru"), "Поддерживает mokaGram")
        XCTAssertEqual(MokoBadges.signatureText(kind: .sub, signature: "", languageCode: "en"), "Supports mokaGram")
    }

    func testSignatureTextIsCutTo64() {
        let long = String(repeating: "я", count: 100)
        XCTAssertEqual(MokoBadges.signatureText(kind: .sub, signature: long, languageCode: "ru")?.count, 64)
    }

    func testSignatureTextFromList() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        XCTAssertEqual(MokoBadges.signatureText(userId: 1, languageCode: "ru"), "Поддержка")
        XCTAssertEqual(MokoBadges.signatureText(userId: 2, languageCode: "ru"), "Поддерживает mokaGram")
        XCTAssertNil(MokoBadges.signatureText(userId: 999, languageCode: "ru"))
        // A role beats the server signature, and a revoked developer keeps the role.
        XCTAssertEqual(MokoBadges.signatureText(userId: 1, username: "litteraliy", languageCode: "ru"), "Разработчик mokaGram")
        XCTAssertEqual(MokoBadges.signatureText(userId: 6612638154, languageCode: "ru"), "Разработчик и владелец mokaGram")
    }

    func testHelloResync() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        XCTAssertEqual(MokoBadges.handleEvent(name: "hello", data: Data(#"{"rev":5,"resync":true}"#.utf8)), .resync)
        XCTAssertEqual(MokoBadges.handleEvent(name: "hello", data: Data(#"{"rev":5,"resync":false}"#.utf8)), .ignored)
        // The server's revision went backwards: it was reset.
        XCTAssertEqual(MokoBadges.handleEvent(name: "hello", data: Data(#"{"rev":1,"resync":false}"#.utf8)), .resync)
    }

    func testStaleListDoesNotRevertNewerEvents() {
        let cleanup = makeDefaults()
        defer { cleanup() }
        MokoBadges.apply(Data(apiList.utf8))
        _ = MokoBadges.handleEvent(name: "badge", data: Data(#"{"id":6,"type":"revoked","userId":1,"badge":null}"#.utf8))
        XCTAssertFalse(MokoBadges.apply(Data(apiList.utf8)))
        XCTAssertNil(MokoBadges.iconFileId(userId: 1))
    }

    func testEventStreamParserSplitsBlocksAndSkipsPings() {
        var parser = EventStreamParser()
        let stream = ": ping\n\nid: 6\r\nevent: badge\r\ndata: {\"a\":\r\ndata: 1}\r\n\n\nevent: hello\ndata: {}\n\n"
        var events: [EventStreamParser.Event] = []
        for byte in stream.utf8 {
            if let event = parser.feed(byte) {
                events.append(event)
            }
        }
        XCTAssertEqual(events.map { $0.name }, ["badge", "hello"])
        XCTAssertEqual(String(data: events[0].data, encoding: .utf8), "{\"a\":\n1}")
    }
}
