import Foundation

/// Optional values reported by an Ogg Opus header; these do not identify a device.
public struct MokoVoiceMetadata: Equatable {
    public let sampleRate: UInt32?
    public let encoder: String?
}

public enum MokoVoiceMetadataReader {
    public static func parse(_ data: Data) -> MokoVoiceMetadata {
        let bytes = [UInt8](data)
        func find(_ marker: String) -> Int? {
            let needle = Array(marker.utf8)
            guard bytes.count >= needle.count else { return nil }
            for start in 0 ... (bytes.count - needle.count) where bytes[start ..< start + needle.count].elementsEqual(needle) {
                return start
            }
            return nil
        }
        func littleEndian32(at offset: Int) -> UInt32? {
            guard offset >= 0, offset <= bytes.count - 4 else { return nil }
            return UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
        }
        var sampleRate: UInt32?
        if let offset = find("OpusHead"), let rate = littleEndian32(at: offset + 12), rate > 0 {
            sampleRate = rate
        }
        var encoder: String?
        if let offset = find("OpusTags"), let length = littleEndian32(at: offset + 8), length > 0, length < 200 {
            let start = offset + 12
            let end = start + Int(length)
            if end <= bytes.count {
                encoder = String(bytes: bytes[start ..< end], encoding: .utf8)
            }
        }
        return MokoVoiceMetadata(sampleRate: sampleRate, encoder: encoder)
    }
}
