import Foundation

public enum MokoQuickCommands {
    private static let commands: Set<String> = [".calc", ".snip", ".tag", ".note", ".id", ".archive", ".unarchive", ".mute", ".unmute", ".save"]
    private static let aliasPattern = try! NSRegularExpression(pattern: "^[\\p{L}\\p{N}_]{1,24}$")

    public static func parse(_ text: String, accountId: Int64? = nil) -> (name: String, argument: String)? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = text.firstIndex(where: { $0.isWhitespace }) ?? text.endIndex
        let name = text[..<end].lowercased()
        let resolved: String
        if commands.contains(name) {
            resolved = name
        } else if name.hasPrefix("."), let accountId, let target = aliases(accountId: accountId)[String(name.dropFirst())], commands.contains(target) {
            resolved = target
        } else {
            return nil
        }
        return (resolved, String(text[end...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Desktop's `commands.aliases` format: one "alias=command" per line, both without the dot.
    public static func aliases(accountId: Int64) -> [String: String] {
        return parseAliases(MokoSettings.string("commands.aliases", accountId: accountId))
    }

    static func parseAliases(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            let parts = line.contains("=") ? line.split(separator: "=", omittingEmptySubsequences: false).map(String.init) : line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count == 2 else { continue }
            let alias = parts[0].trimmingCharacters(in: .whitespaces).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let command = parts[1].trimmingCharacters(in: .whitespaces).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if !alias.isEmpty && !command.isEmpty {
                result[alias] = "." + command
            }
        }
        return result
    }

    static func formatAliases(_ values: [String: String]) -> String {
        return values.keys.sorted().map { "\($0)=\(values[$0]!.trimmingCharacters(in: CharacterSet(charactersIn: ".")))" }.joined(separator: "\n")
    }

    @discardableResult
    public static func saveAlias(name: String, target: String, accountId: Int64) -> Bool {
        let alias = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let target = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let range = NSRange(location: 0, length: (alias as NSString).length)
        guard aliasPattern.firstMatch(in: alias, range: range)?.range == range, !commands.contains("." + alias), target.isEmpty || commands.contains("." + target) else { return false }
        var values = aliases(accountId: accountId)
        if target.isEmpty { values.removeValue(forKey: alias) } else { values[alias] = "." + target }
        MokoSettings.set(.string(formatAliases(values)), for: "commands.aliases", accountId: accountId)
        return true
    }

    public static func enabled(accountId: Int64) -> Bool {
        return MokoSettings.bool("commands.enabled", accountId: accountId)
    }

    public static func setEnabled(_ value: Bool, accountId: Int64) {
        MokoSettings.set(.bool(value), for: "commands.enabled", accountId: accountId)
    }

    /// A blank or zero duration means indefinitely. Timed mutes are limited to one year.
    public static func muteDuration(_ argument: String) -> Int32? {
        let value = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.isEmpty { return Int32.max }
        let expression = try! NSRegularExpression(pattern: "^([0-9]+)\\s*([mhdwмчдн]?)$")
        let string = value as NSString
        guard let match = expression.firstMatch(in: value, range: NSRange(location: 0, length: string.length)),
              let amount = Int64(string.substring(with: match.range(at: 1))) else { return nil }
        if amount == 0 { return Int32.max }
        let unit = string.substring(with: match.range(at: 2))
        let factor: Int64
        switch unit {
        case "", "m", "м": factor = 60
        case "h", "ч": factor = 3600
        case "d", "д": factor = 86400
        case "w", "н": factor = 604800
        default: return nil
        }
        let (seconds, overflow) = amount.multipliedReportingOverflow(by: factor)
        let latestSafeInterval = Int64(Int32.max) - Int64(Date().timeIntervalSince1970) - 60
        guard !overflow, seconds <= 365 * 86400, seconds <= latestSafeInterval else { return nil }
        return Int32(seconds)
    }

    /// Returns nil for invalid expressions, division by zero and non-finite results.
    public static func calculate(_ expression: String) -> String? {
        let normalized = expression.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "÷", with: "/").filter { !$0.isWhitespace }
        guard !normalized.isEmpty, normalized.count <= 256 else { return nil }
        var parser = Calculator(Array(normalized))
        guard let value = try? parser.parse(), value.isFinite else { return nil }
        if abs(value - value.rounded()) < 1e-9 && abs(value) < 1e15 {
            return String(Int64(value.rounded()))
        }
        return String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private struct Calculator {
        enum Failure: Error { case invalid }
        let input: [Character]
        var index = 0
        init(_ input: [Character]) { self.input = input }
        var current: Character? { index < input.count ? input[index] : nil }
        mutating func consume(_ value: Character) -> Bool {
            guard current == value else { return false }
            index += 1
            return true
        }
        mutating func parse() throws -> Double {
            let value = try expression()
            guard index == input.count, value.isFinite else { throw Failure.invalid }
            return value
        }
        mutating func expression() throws -> Double {
            var value = try term()
            while current == "+" || current == "-" {
                let add = consume("+")
                if !add { _ = consume("-") }
                let rhs = try term()
                value = add ? value + rhs : value - rhs
            }
            return value
        }
        mutating func term() throws -> Double {
            var value = try power()
            while current == "*" || current == "/" {
                if current == "*", index + 1 < input.count, input[index + 1] == "*" { break }
                let multiply = consume("*")
                if !multiply { _ = consume("/") }
                let rhs = try power()
                if !multiply && rhs == 0 { throw Failure.invalid }
                value = multiply ? value * rhs : value / rhs
            }
            return value
        }
        mutating func power() throws -> Double {
            let value = try unary()
            if consume("^") { return pow(value, try power()) }
            if current == "*", index + 1 < input.count, input[index + 1] == "*" {
                index += 2
                return pow(value, try power())
            }
            return value
        }
        mutating func unary() throws -> Double {
            if consume("-") { return -(try unary()) }
            if consume("+") { return try unary() }
            var value = try atom()
            while consume("%") { value /= 100 }
            return value
        }
        mutating func atom() throws -> Double {
            if consume("(") {
                let value = try expression()
                guard consume(")") else { throw Failure.invalid }
                return value
            }
            if let current, current.isASCII && (current.isNumber || current == ".") {
                let start = index
                while let c = self.current, c.isASCII && (c.isNumber || c == ".") { index += 1 }
                guard let value = Double(String(input[start ..< index])) else { throw Failure.invalid }
                return value
            }
            if let current, current.isASCII && current.isLetter {
                let start = index
                while let c = self.current, c.isASCII && c.isLetter { index += 1 }
                let name = String(input[start ..< index]).lowercased()
                if name == "pi" { return .pi }
                if name == "e" { return exp(1) }
                guard consume("(") else { throw Failure.invalid }
                let value = try expression()
                guard consume(")") else { throw Failure.invalid }
                switch name {
                case "sqrt": return sqrt(value)
                case "abs": return abs(value)
                case "sin": return sin(value)
                case "cos": return cos(value)
                case "tan": return tan(value)
                case "ln": return log(value)
                case "log": return log10(value)
                case "floor": return floor(value)
                case "ceil": return ceil(value)
                case "round": return value.rounded(.toNearestOrAwayFromZero)
                default: throw Failure.invalid
                }
            }
            throw Failure.invalid
        }
    }
}
