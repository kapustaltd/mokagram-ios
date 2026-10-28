import Foundation

/// mokaGram's own interface strings. The Russian text is the key, as on Desktop: Russian,
/// Ukrainian and Belarusian interfaces show it as is, every other language gets the English
/// translation, or the Russian text when there is none.
public enum MokoStrings {
    private static let russianFamily: Set<String> = ["ru", "uk", "be"]

    /// Whether this interface language shows the Russian text as is.
    public static func isRussianFamily(languageCode: String) -> Bool {
        let base = languageCode.split(separator: "-").first.map { String($0).lowercased() } ?? ""
        return russianFamily.contains(base)
    }

    public static func tr(_ russian: String, languageCode: String) -> String {
        if isRussianFamily(languageCode: languageCode) {
            return russian
        }
        return mokoEnglishTable[russian] ?? russian
    }

    /// `%1`, `%2`… are replaced by `args` in order, as in Desktop's `tr::…(…).arg(…)`.
    public static func tr(_ russian: String, languageCode: String, _ args: String...) -> String {
        var result = tr(russian, languageCode: languageCode)
        for (index, arg) in args.enumerated().reversed() {
            result = result.replacingOccurrences(of: "%\(index + 1)", with: arg)
        }
        return result
    }
}
