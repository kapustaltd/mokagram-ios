import Foundation
import XCTest
import SwiftSignalKit
import MokoCore

final class MokoSettingsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        self.defaults = UserDefaults(suiteName: "moko.test.\(UUID().uuidString)")!
        MokoStorage._resetForTesting(defaults: self.defaults)
    }

    private func registerTestEntries() {
        MokoSettings.register([
            MokoSettingEntry(key: "test.device", page: .system, section: "Тест", title: "Устройство", description: "", kind: .bool, defaultValue: .bool(false), scope: .device),
            MokoSettingEntry(key: "test.count", page: .system, section: "Тест", title: "Число", description: "", kind: .int(min: 1, max: 10), defaultValue: .int(5), scope: .account),
        ])
    }

    func testDefaultsWithoutWrites() {
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertTrue(MokoSettings.bool("ghost.read", accountId: 1))
        XCTAssertEqual(MokoSettings.string("ghost.schedule_from", accountId: 1), "23:00")
    }

    func testSettingDefaultRemovesKey() {
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        XCTAssertNotNil(self.defaults.object(forKey: "mokoGram.s.1.ghost.enabled"))
        MokoSettings.set(.bool(false), for: "ghost.enabled", accountId: 1)
        XCTAssertNil(self.defaults.object(forKey: "mokoGram.s.1.ghost.enabled"))
        XCTAssertFalse(MokoSettings.isChanged("ghost.enabled", accountId: 1))
    }

    func testAccountScopeIsolation() {
        self.registerTestEntries()
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        XCTAssertTrue(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 2))
        MokoSettings.set(.bool(true), for: "test.device", accountId: 1)
        XCTAssertTrue(MokoSettings.bool("test.device", accountId: 2))
        XCTAssertNotNil(self.defaults.object(forKey: "mokoGram.s.device.test.device"))
    }

    func testResetPageKeepsOthers() {
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        MokoSettings.set(.bool(true), for: "commands.enabled", accountId: 1)
        MokoSettings.reset(page: .privacy, accountId: 1)
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertTrue(MokoSettings.bool("commands.enabled", accountId: 1))
        MokoSettings.resetAll(accountId: 1)
        XCTAssertFalse(MokoSettings.bool("commands.enabled", accountId: 1))
    }

    func testDidChangePosted() {
        let expectation = self.expectation(forNotification: MokoSettings.didChange, object: nil) { notification in
            return notification.userInfo?["key"] as? String == "ghost.enabled"
        }
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        self.wait(for: [expectation], timeout: 1.0)
    }

    func testIntClampsAndChoiceRange() {
        self.registerTestEntries()
        MokoSettings.set(.int(50), for: "test.count", accountId: 1)
        XCTAssertEqual(MokoSettings.int("test.count", accountId: 1), 10)
        MokoSettings.set(.int(-3), for: "test.count", accountId: 1)
        XCTAssertEqual(MokoSettings.int("test.count", accountId: 1), 1)
    }

    func testBoolSignalEmitsCurrentAndUpdates() {
        var values: [Bool] = []
        let disposable = MokoSettings.boolSignal("ghost.enabled", accountId: 1).start(next: { values.append($0) })
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        disposable.dispose()
        XCTAssertEqual(values, [false, true])
    }
}
