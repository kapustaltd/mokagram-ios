import Foundation
import XCTest
import MokoCore

final class MokoSettingsFileTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MokoStorage._resetForTesting(defaults: UserDefaults(suiteName: "moko.test.\(UUID().uuidString)")!)
    }

    private func file(_ values: String, version: Int = 1, format: String = "mokaset") -> Data {
        return "{\"format\":\"\(format)\",\"version\":\(version),\"values\":\(values)}".data(using: .utf8)!
    }

    private func fixture(_ name: String) throws -> Data {
        let root = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
        return try Data(contentsOf: URL(fileURLWithPath: root).appendingPathComponent("_main/submodules/Moko/MokoCore/Tests/Fixtures/\(name)"))
    }

    func testRoundTrip() {
        MokoSettings.set(.bool(true), for: "ghost.enabled", accountId: 1)
        MokoSettings.set(.bool(false), for: "ghost.read", accountId: 1)
        MokoSettings.set(.bool(true), for: "commands.enabled", accountId: 1)
        let data = MokoSettingsFile.export(accountId: 1, appVersion: "13.0-moka")
        MokoSettings.resetAll(accountId: 1)
        XCTAssertEqual(try MokoSettingsFile.apply(data, accountId: 1).get(), MokoImportSummary(changed: 3, unknown: 0, invalid: 0))
        XCTAssertTrue(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertFalse(MokoSettings.bool("ghost.read", accountId: 1))
        XCTAssertTrue(MokoSettings.bool("commands.enabled", accountId: 1))
    }

    func testExportOnlyDifferences() throws {
        let data = MokoSettingsFile.export(accountId: 1, appVersion: "13.0-moka")
        let root = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(root["format"] as? String, "mokaset")
        XCTAssertEqual(root["version"] as? Int, 1)
        XCTAssertEqual((root["values"] as? [String: Any])?.count, 0)
    }

    func testImportDesktopDefaultsKeepsGhostOff() {
        let result = MokoSettingsFile.apply(file("{\"ghost.read\":true}"), accountId: 1)
        XCTAssertEqual(try result.get(), MokoImportSummary(changed: 0, unknown: 0, invalid: 0))
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 1))
    }

    func testPreviewCountsUnknownAndInvalid() {
        let data = file("{\"ghost.enabled\":true,\"lag.level\":2,\"commands.enabled\":\"yes\"}")
        XCTAssertEqual(try MokoSettingsFile.preview(data, accountId: 1).get(), MokoImportSummary(changed: 1, unknown: 1, invalid: 1))
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 1))
    }

    func testRejectsNewerVersionAndOtherFormats() {
        XCTAssertEqual(MokoSettingsFile.preview(file("{}", version: 2), accountId: 1), .failure(.newerVersion))
        XCTAssertEqual(MokoSettingsFile.preview(file("{}", format: "x"), accountId: 1), .failure(.notMokaset))
        XCTAssertEqual(MokoSettingsFile.preview("nope".data(using: .utf8)!, accountId: 1), .failure(.notJson))
        XCTAssertEqual(MokoSettingsFile.preview("{\"format\":\"mokaset\",\"version\":1}".data(using: .utf8)!, accountId: 1), .failure(.noValues))
    }

    func testUnknownKeysSurviveExport() throws {
        _ = MokoSettingsFile.apply(file("{\"lag.level\":2}"), accountId: 1)
        let root = try JSONSerialization.jsonObject(with: MokoSettingsFile.export(accountId: 1, appVersion: "x")) as! [String: Any]
        XCTAssertEqual((root["values"] as? [String: Any])?["lag.level"] as? Int, 2)
    }

    func testDesktopFixture() throws {
        let summary = try MokoSettingsFile.apply(try fixture("desktop.mokaset"), accountId: 1).get()
        XCTAssertTrue(MokoSettings.bool("ghost.enabled", accountId: 1))
        XCTAssertFalse(MokoSettings.bool("ghost.typing", accountId: 1))
        XCTAssertTrue(MokoSettings.bool("commands.enabled", accountId: 1))
        XCTAssertGreaterThanOrEqual(summary.unknown, 1)
    }

    func testUnknownKeysAreAccountScoped() throws {
        _ = MokoSettingsFile.apply(file("{\"lag.level\":2}"), accountId: 1)
        let other = try JSONSerialization.jsonObject(with: MokoSettingsFile.export(accountId: 2, appVersion: "x")) as! [String: Any]
        XCTAssertNil((other["values"] as? [String: Any])?["lag.level"])
    }

    func testRegisteringImportedUnknownKeyAppliesIt() throws {
        _ = MokoSettingsFile.apply(file("{\"test.later\":7}"), accountId: 1)
        MokoSettings.register([MokoSettingEntry(key: "test.later", page: .system, section: "Тест", title: "Позже", description: "", kind: .int(min: 0, max: 10), defaultValue: .int(1), scope: .account)])
        XCTAssertEqual(MokoSettings.int("test.later", accountId: 1), 7)
        XCTAssertEqual(MokoSettings.int("test.later", accountId: 2), 1)
        MokoSettings.reset("test.later", accountId: 1)
        let root = try JSONSerialization.jsonObject(with: MokoSettingsFile.export(accountId: 1, appVersion: "x")) as! [String: Any]
        XCTAssertNil((root["values"] as? [String: Any])?["test.later"], "a reset value must not come back from the import store")
    }

    func testResetAllClearsUnknownKeys() throws {
        _ = MokoSettingsFile.apply(file("{\"lag.level\":2}"), accountId: 1)
        MokoSettings.resetAll(accountId: 1)
        let root = try JSONSerialization.jsonObject(with: MokoSettingsFile.export(accountId: 1, appVersion: "x")) as! [String: Any]
        XCTAssertEqual((root["values"] as? [String: Any])?.count, 0)
    }
}
