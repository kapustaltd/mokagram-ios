import Foundation

/// Album art of mokaGram's own audio files (SoundCloud tracks): the app's album-art fetcher loads
/// a registered file's cover from this URL instead of asking Telegram by title and performer.
public enum MokoArtworkRegistry {
    private static let lock = NSLock()
    private static var urls: [Int64: URL] = [:]

    public static func register(fileId: Int64, url: URL) {
        lock.lock()
        urls[fileId] = url
        lock.unlock()
    }

    public static func url(fileId: Int64) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return urls[fileId]
    }
}
