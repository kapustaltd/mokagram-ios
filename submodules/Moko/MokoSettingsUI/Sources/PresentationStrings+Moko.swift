import Foundation
import TelegramPresentationData
import MokoCore

extension PresentationStrings {
    /// A mokaGram string in the current interface language (`MokoStrings`), `%1`… replaced by `args`.
    public func moko(_ russian: String, _ args: String...) -> String {
        var result = MokoStrings.tr(russian, languageCode: self.baseLanguageCode)
        for (index, arg) in args.enumerated().reversed() {
            result = result.replacingOccurrences(of: "%\(index + 1)", with: arg)
        }
        return result
    }
}
