import Foundation
import XCTest
import MokoCore

final class MokoStreamerTests: XCTestCase {
    private let bullet = "\u{2022}"

    override func setUp() {
        super.setUp()
        MokoStorage._resetForTesting(defaults: UserDefaults(suiteName: "moko.test.\(UUID().uuidString)")!)
    }

    private func dots(_ count: Int) -> String {
        return String(repeating: bullet, count: count)
    }

    func testPhoneKeepsShape() {
        XCTAssertEqual(MokoStreamer.mask(.phone, "+7 912 345-67-89"), "+" + dots(1) + " " + dots(3) + " " + dots(3) + "-" + dots(2) + "-" + dots(2))
        XCTAssertEqual(MokoStreamer.mask(.phone, "+888676767"), "+" + dots(9))
    }

    func testUsernameLengthIsClamped() {
        XCTAssertEqual(MokoStreamer.mask(.username, "@ecronx"), "@" + dots(6))
        XCTAssertEqual(MokoStreamer.mask(.username, "@ab"), "@" + dots(5))
        XCTAssertEqual(MokoStreamer.mask(.username, "averyveryverylongusername"), dots(16))
    }

    func testLinkMasksOnlyThePath() {
        XCTAssertEqual(MokoStreamer.mask(.link, "https://t.me/ecronx"), "https://t.me/" + dots(6))
        XCTAssertEqual(MokoStreamer.mask(.link, "t.me/ecronx"), "t.me/" + dots(6))
        XCTAssertEqual(MokoStreamer.mask(.link, "https://t.me"), "https://t.me")
        XCTAssertEqual(MokoStreamer.mask(.link, "https://t.me/"), "https://t.me/")
    }

    func testIdAndName() {
        XCTAssertEqual(MokoStreamer.mask(.id, "1234"), dots(9))
        XCTAssertEqual(MokoStreamer.mask(.name, "Иван Петров"), "И" + dots(3))
        XCTAssertEqual(MokoStreamer.mask(.notify, "text"), "text")
        XCTAssertEqual(MokoStreamer.mask(.phone, ""), "")
    }

    func testActiveNeedsMasterAndFlag() {
        XCTAssertFalse(MokoStreamer.isActive(.phone, accountId: 1))
        MokoSettings.set(.bool(true), for: "streamer.enabled", accountId: 1)
        XCTAssertTrue(MokoStreamer.isActive(.phone, accountId: 1))
        XCTAssertFalse(MokoStreamer.isActive(.name, accountId: 1))
        MokoSettings.set(.bool(false), for: "streamer.phone", accountId: 1)
        XCTAssertFalse(MokoStreamer.isActive(.phone, accountId: 1))
    }

    func testCopyModes() {
        XCTAssertEqual(MokoStreamer.forCopy(.phone, "+1234", accountId: 1), "+1234")
        MokoSettings.set(.bool(true), for: "streamer.enabled", accountId: 1)
        XCTAssertEqual(MokoStreamer.forCopy(.phone, "+1234", accountId: 1), "+1234")
        MokoSettings.set(.int(1), for: "streamer.copy", accountId: 1)
        XCTAssertNil(MokoStreamer.forCopy(.phone, "+1234", accountId: 1))
        XCTAssertEqual(MokoStreamer.forCopy(.name, "Иван", accountId: 1), "Иван")
        MokoSettings.set(.int(2), for: "streamer.copy", accountId: 1)
        XCTAssertEqual(MokoStreamer.forCopy(.phone, "+1234", accountId: 1), "+" + dots(4))
        XCTAssertEqual(MokoStreamer.displayed(.phone, "+1234", accountId: 1), "+" + dots(4))
    }

    func testCopyWithAuthor() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let text = MokoMisc.copyWithAuthor(date: date, author: "Аня", text: "привет", timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(text, "[14.11.2023 22:13] Аня: привет")
    }

    func testStickerSetOwner() {
        XCTAssertEqual(MokoMisc.probableStickerSetOwnerId(setId: 0x0000_0001_0000_0000), 1)
        XCTAssertEqual(MokoMisc.probableStickerSetOwnerId(setId: (7 << 32) | (0x3F << 16)), 7 | 0x80000000)
        XCTAssertEqual(MokoMisc.probableStickerSetOwnerId(setId: (7 << 32) | (1 << 24)), 7 + 0x100000000)
    }
}
