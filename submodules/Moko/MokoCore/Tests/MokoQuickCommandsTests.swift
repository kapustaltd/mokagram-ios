import Foundation
import XCTest
import MokoCore

final class MokoQuickCommandsTests: XCTestCase {
    func testCalculator() {
        XCTAssertEqual(MokoQuickCommands.parse(" .CALC 2 + 2 ")?.name, ".calc")
        XCTAssertEqual(MokoQuickCommands.parse(" .CALC 2 + 2 ")?.argument, "2 + 2")
        XCTAssertEqual(MokoQuickCommands.parse(".tag")?.argument, "")
        XCTAssertEqual(MokoQuickCommands.parse(".id")?.name, ".id")
        XCTAssertEqual(MokoQuickCommands.parse(".archive")?.name, ".archive")
        XCTAssertEqual(MokoQuickCommands.parse(".save")?.name, ".save")
        XCTAssertNil(MokoQuickCommands.parse(".calculator 2"))
        XCTAssertNil(MokoQuickCommands.parse("hello .calc 2"))
        XCTAssertEqual(MokoQuickCommands.calculate("2 + 3 * 4"), "14")
        XCTAssertEqual(MokoQuickCommands.calculate("2^3^2"), "512")
        XCTAssertEqual(MokoQuickCommands.calculate("sqrt(81) + 50%"), "9.5")
        XCTAssertEqual(MokoQuickCommands.calculate("1,5 × 2"), "3")
        XCTAssertEqual(MokoQuickCommands.calculate("abs(-3) + round(1.5)"), "5")
        XCTAssertNil(MokoQuickCommands.calculate("1 / 0"))
        XCTAssertNil(MokoQuickCommands.calculate("sqrt(-1)"))
        XCTAssertNil(MokoQuickCommands.calculate("2 +"))
        XCTAssertNil(MokoQuickCommands.calculate("2garbage"))
        XCTAssertNil(MokoQuickCommands.calculate(String(repeating: "1", count: 257)))
        XCTAssertEqual(MokoQuickCommands.muteDuration(""), Int32.max)
        XCTAssertEqual(MokoQuickCommands.muteDuration("0"), Int32.max)
        XCTAssertEqual(MokoQuickCommands.muteDuration("30m"), 1800)
        XCTAssertEqual(MokoQuickCommands.muteDuration("2 ч"), 7200)
        XCTAssertEqual(MokoQuickCommands.muteDuration("1w"), 604800)
        XCTAssertNil(MokoQuickCommands.muteDuration("9999999999999999999999999d"))
        XCTAssertNil(MokoQuickCommands.muteDuration("366d"))
        XCTAssertNil(MokoQuickCommands.muteDuration("2x"))
    }

    func testSettingIsAccountSpecific() {
        let suite = "MokoQuickCommandsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertFalse(MokoQuickCommands.enabled(accountId: 1))
        MokoQuickCommands.setEnabled(true, accountId: 1)
        XCTAssertTrue(MokoQuickCommands.enabled(accountId: 1))
        XCTAssertFalse(MokoQuickCommands.enabled(accountId: 2))
        XCTAssertTrue(MokoQuickCommands.saveAlias(name: "sum", target: "calc", accountId: 1))
        XCTAssertEqual(MokoQuickCommands.parse(".sum 2+2", accountId: 1)?.name, ".calc")
        XCTAssertNil(MokoQuickCommands.parse(".sum 2+2", accountId: 2))
        XCTAssertFalse(MokoQuickCommands.saveAlias(name: "calc", target: "id", accountId: 1))
        XCTAssertFalse(MokoQuickCommands.saveAlias(name: "x", target: "unimplemented", accountId: 1))
        XCTAssertTrue(MokoQuickCommands.saveAlias(name: "sum", target: "", accountId: 1))
        XCTAssertNil(MokoQuickCommands.parse(".sum 2+2", accountId: 1))
    }
}
