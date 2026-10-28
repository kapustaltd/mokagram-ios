import Foundation
import XCTest
import MokoCore

final class MokoStringsTests: XCTestCase {
    func testRussianFamilyKeepsRussian() {
        XCTAssertEqual(MokoStrings.tr("(пусто)", languageCode: "uk"), "(пусто)")
        XCTAssertEqual(MokoStrings.tr("(пусто)", languageCode: "be"), "(пусто)")
    }

    func testEnglishForOthers() {
        XCTAssertEqual(MokoStrings.tr("(пусто)", languageCode: "de"), "(empty)")
    }

    func testMissingFallsBackToRussian() {
        XCTAssertEqual(MokoStrings.tr("нет такого", languageCode: "en"), "нет такого")
    }

    func testArgs() {
        XCTAssertEqual(MokoStrings.tr("  (чатов: %1)", languageCode: "en", "3"), "  (chats: 3)")
        XCTAssertEqual(MokoStrings.tr("  (чатов: %1)", languageCode: "ru", "3"), "  (чатов: 3)")
    }

    func testBaseLanguageCode() {
        XCTAssertEqual(MokoStrings.tr("(пусто)", languageCode: "ru-RU"), "(пусто)")
        XCTAssertEqual(MokoStrings.tr("(пусто)", languageCode: "en-GB"), "(empty)")
    }

    func testIosTableOverridesAndBuiltinTitlesAreTranslated() {
        XCTAssertEqual(MokoStrings.tr("Скрывать действия в чате", languageCode: "en"), "Hide chat activity")
        for entry in MokoBuiltinSettings.entries {
            XCTAssertNotEqual(MokoStrings.tr(entry.title, languageCode: "en"), entry.title, entry.key)
        }
    }
}
