import Foundation
import XCTest
import MokoCore

final class MokoLegacyMigrationTests: XCTestCase {
    private var legacy: UserDefaults!
    private var shared: UserDefaults!

    override func setUp() {
        super.setUp()
        self.legacy = UserDefaults(suiteName: "moko.legacy.\(UUID().uuidString)")!
        self.shared = UserDefaults(suiteName: "moko.shared.\(UUID().uuidString)")!
        MokoStorage._resetForTesting(defaults: self.shared)
    }

    func testMigratesLegacyTypingFlag() {
        self.legacy.set(true, forKey: "mokoGram.hideTyping.7")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertTrue(MokoSettings.bool("ghost.enabled", accountId: 7))
        XCTAssertTrue(MokoSettings.bool("ghost.typing", accountId: 7))
        XCTAssertFalse(MokoSettings.bool("ghost.read", accountId: 7))
        XCTAssertFalse(MokoSettings.bool("ghost.online", accountId: 7))
        XCTAssertFalse(MokoSettings.bool("ghost.stories", accountId: 7))
        XCTAssertNil(self.legacy.object(forKey: "mokoGram.hideTyping.7"))
    }

    func testAccountWithoutLegacyFlagsStaysOff() {
        self.legacy.set(false, forKey: "mokoGram.hideTyping.8")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 8))
    }

    func testMigratesSchedule() {
        self.legacy.set(true, forKey: "mokoGram.ghostSchedule.enabled.7")
        self.legacy.set("22:30", forKey: "mokoGram.ghostSchedule.from.7")
        self.legacy.set(false, forKey: "mokoGram.ghostSchedule.typing.7")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertTrue(MokoSettings.bool("ghost.schedule", accountId: 7))
        XCTAssertEqual(MokoSettings.string("ghost.schedule_from", accountId: 7), "22:30")
        XCTAssertFalse(MokoSettings.bool("ghost.sched_typing", accountId: 7))
    }

    func testMigratesCommandsAndAliases() {
        self.legacy.set(true, forKey: "mokoGram.quickCommands.7")
        self.legacy.set(["sum": ".calc", "a": ".archive"], forKey: "mokoGram.commandAliases.7")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertTrue(MokoSettings.bool("commands.enabled", accountId: 7))
        XCTAssertEqual(MokoSettings.string("commands.aliases", accountId: 7), "a=archive\nsum=calc")
        XCTAssertEqual(MokoQuickCommands.parse(".sum 1+1", accountId: 7)?.name, ".calc")
    }

    func testMovesDataKeys() {
        self.legacy.set(["hi": "Hello"], forKey: "mokoGram.snippets.7")
        self.legacy.set(true, forKey: "mokoGram.automaticReadException.7.42")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertEqual(MokoSnippets.all(accountId: 7), ["hi": "Hello"])
        XCTAssertTrue(MokoPrivacySettings.allowsAutomaticRead(accountId: 7, peerId: 42))
        XCTAssertNil(self.legacy.object(forKey: "mokoGram.snippets.7"))
    }

    func testRunsOnce() {
        MokoLegacyMigration.run(legacy: self.legacy)
        self.legacy.set(true, forKey: "mokoGram.hideTyping.9")
        MokoLegacyMigration.run(legacy: self.legacy)
        XCTAssertFalse(MokoSettings.bool("ghost.enabled", accountId: 9))
        XCTAssertNotNil(self.legacy.object(forKey: "mokoGram.hideTyping.9"))
    }
}
