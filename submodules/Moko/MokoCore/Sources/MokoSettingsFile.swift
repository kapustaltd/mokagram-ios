import Foundation

public struct MokoImportSummary: Equatable {
    /// Values that would change the current settings.
    public var changed: Int
    /// Keys with no registered entry (a plugin that is not loaded). They are kept.
    public var unknown: Int
    /// Values of the wrong type or out of range. They are skipped.
    public var invalid: Int

    public init(changed: Int, unknown: Int, invalid: Int) {
        self.changed = changed
        self.unknown = unknown
        self.invalid = invalid
    }
}

public enum MokoSettingsFileError: Error, Equatable {
    case notJson
    case notMokaset
    case newerVersion
    case noValues
}

/// `.mokaset` files, the same format Desktop writes:
/// `{"format":"mokaset","app":…,"version":1,"values":{key: value}}` with only non-default values.
public enum MokoSettingsFile {
    static let formatVersion = 1
    private static let unknownPrefix = "mokoGram.s.unknown."

    public static func export(accountId: Int64, appVersion: String) -> Data {
        let defaults = MokoStorage.defaults
        var values: [String: Any] = [:]
        for entry in MokoSettings.entries() where entry.kind != .action && MokoSettings.isChanged(entry.key, accountId: accountId) {
            switch MokoSettings.value(entry.key, accountId: accountId) {
            case let .bool(value)?:
                values[entry.key] = value
            case let .int(value)?:
                values[entry.key] = value
            case let .string(value)?:
                values[entry.key] = value
            case nil:
                break
            }
        }
        for (storageKey, raw) in defaults.dictionaryRepresentation() where storageKey.hasPrefix(unknownPrefix) {
            let key = String(storageKey.dropFirst(unknownPrefix.count))
            if values[key] == nil, let text = raw as? String, let data = text.data(using: .utf8), let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                values[key] = value
            }
        }
        let root: [String: Any] = ["format": "mokaset", "app": appVersion, "version": formatVersion, "values": values]
        return (try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    public static func preview(_ data: Data, accountId: Int64) -> Result<MokoImportSummary, MokoSettingsFileError> {
        return process(data, accountId: accountId, apply: false)
    }

    public static func apply(_ data: Data, accountId: Int64) -> Result<MokoImportSummary, MokoSettingsFileError> {
        return process(data, accountId: accountId, apply: true)
    }

    private static func process(_ data: Data, accountId: Int64, apply: Bool) -> Result<MokoImportSummary, MokoSettingsFileError> {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .failure(.notJson)
        }
        guard root["format"] as? String == "mokaset" else {
            return .failure(.notMokaset)
        }
        if let version = root["version"] as? Int, version > formatVersion {
            return .failure(.newerVersion)
        }
        guard let values = root["values"] as? [String: Any] else {
            return .failure(.noValues)
        }
        var summary = MokoImportSummary(changed: 0, unknown: 0, invalid: 0)
        for key in values.keys.sorted() {
            let raw = values[key]!
            guard let entry = MokoSettings.entry(key) else {
                summary.unknown += 1
                if apply, let encoded = try? JSONSerialization.data(withJSONObject: raw, options: [.fragmentsAllowed]), let text = String(data: encoded, encoding: .utf8) {
                    MokoStorage.defaults.set(text, forKey: unknownPrefix + key)
                }
                continue
            }
            guard let value = decode(raw, for: entry) else {
                summary.invalid += 1
                continue
            }
            if value != MokoSettings.value(key, accountId: accountId) {
                summary.changed += 1
                if apply {
                    MokoSettings.set(value, for: key, accountId: accountId)
                }
            }
        }
        return .success(summary)
    }

    /// A JSON value as a value of this entry, or nil when it does not fit.
    private static func decode(_ raw: Any, for entry: MokoSettingEntry) -> MokoSettingValue? {
        let isBoolean = (raw as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() } ?? false
        switch entry.defaultValue {
        case .bool:
            return isBoolean ? .bool((raw as! NSNumber).boolValue) : nil
        case .int:
            guard !isBoolean, let number = raw as? NSNumber, Double(number.intValue) == number.doubleValue else {
                return nil
            }
            let value = number.intValue
            switch entry.kind {
            case let .int(minValue, maxValue):
                return (value >= minValue && value <= maxValue) ? .int(value) : nil
            case let .choice(captions):
                return (value >= 0 && value < captions.count) ? .int(value) : nil
            default:
                return .int(value)
            }
        case .string:
            guard let text = raw as? String else {
                return nil
            }
            if entry.kind == .color, text.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) == nil, !text.isEmpty {
                return nil
            }
            return .string(text)
        }
    }
}
