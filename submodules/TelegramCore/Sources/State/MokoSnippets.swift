import Foundation

/// Device-local, account-specific text snippets used in the message composer.
public enum MokoSnippets {
    private static let pattern = try! NSRegularExpression(pattern: "(?<!\\S);([\\p{L}\\p{N}_]{1,24})(?![\\p{L}\\p{N}_])")
    private static let validName = try! NSRegularExpression(pattern: "^[\\p{L}\\p{N}_]{1,24}$")

    private static func key(_ accountId: Int64) -> String {
        return "mokoGram.snippets.\(accountId)"
    }

    public static func all(accountId: Int64, defaults: UserDefaults = .standard) -> [String: String] {
        return defaults.dictionary(forKey: key(accountId)) as? [String: String] ?? [:]
    }

    @discardableResult
    public static func save(name: String, text: String, accountId: Int64, defaults: UserDefaults = .standard) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let range = NSRange(location: 0, length: (name as NSString).length)
        guard validName.firstMatch(in: name, range: range)?.range == range else {
            return false
        }
        var snippets = all(accountId: accountId, defaults: defaults)
        if text.isEmpty {
            snippets.removeValue(forKey: name)
        } else {
            snippets[name] = String(text.prefix(4000))
        }
        defaults.set(snippets, forKey: key(accountId))
        return true
    }

    public static func expand(_ text: NSAttributedString, accountId: Int64, defaults: UserDefaults = .standard) -> NSAttributedString {
        guard text.string.contains(";") else { return text }
        let snippets = all(accountId: accountId, defaults: defaults)
        guard !snippets.isEmpty else { return text }
        let source = text.string as NSString
        let matches = pattern.matches(in: text.string, range: NSRange(location: 0, length: source.length))
        let result = NSMutableAttributedString(attributedString: text)
        for match in matches.reversed() {
            let name = source.substring(with: match.range(at: 1)).lowercased()
            if let replacement = snippets[name] {
                result.replaceCharacters(in: match.range, with: NSAttributedString(string: replacement))
            }
        }
        return result
    }
}
