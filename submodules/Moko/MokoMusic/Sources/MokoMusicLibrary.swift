import Foundation
import SwiftSignalKit

/// Likes and listening history, stored as Desktop's `mokagram_music/library.json`
/// (mokagram_music_library.cpp), so a Desktop file reads unchanged.
public final class MokoMusicLibrary {
    static let historyLimit = 3000

    struct Liked {
        var track: MokoMusicTrack
        var at: Int64
    }

    struct Listen {
        var id: String
        var artistId: String
        var genre: String
        var tags: [String]
        var durationMs: Int
        var listenedMs: Int
        var finished: Bool
        var at: Int64
    }

    private let file: URL
    let now: () -> Date
    private let lock = NSLock()
    private(set) var liked: [Liked] = []
    private(set) var history: [Listen] = []
    /// Tracks of recent "For you" picks, not stored (Desktop's `ShownRecently`).
    var shownRecently: Set<String> = []
    private let changedPipe = ValuePipe<Void>()

    public var changed: Signal<Void, NoError> {
        return self.changedPipe.signal()
    }

    public init(file: URL, now: @escaping () -> Date = Date.init) {
        self.file = file
        self.now = now
        self.load()
    }

    var nowSeconds: Int64 {
        return Int64(self.now().timeIntervalSince1970)
    }

    private static func string(_ value: Any?) -> String {
        return value as? String ?? ""
    }

    private static func number(_ value: Any?) -> Double {
        return (value as? NSNumber)?.doubleValue ?? 0
    }

    private static func json(_ track: MokoMusicTrack) -> [String: Any] {
        return ["id": track.id, "title": track.title, "artist": track.artist, "art": track.artworkUrl, "link": track.permalink, "dur": track.durationMs, "aid": track.artistId, "genre": track.genre, "tags": track.tags, "plays": Double(track.playbackCount), "likes": Double(track.likesCount), "created": Double(track.createdAt)]
    }

    private static func track(_ object: [String: Any]) -> MokoMusicTrack {
        return MokoMusicTrack(id: string(object["id"]), title: string(object["title"]), artist: string(object["artist"]), artworkUrl: string(object["art"]), permalink: string(object["link"]), transcodingUrl: "", authorization: "", fileExtension: "mp3", durationMs: Int(number(object["dur"])), isHls: false, artistId: string(object["aid"]), genre: string(object["genre"]), tags: object["tags"] as? [String] ?? [], playbackCount: Int64(number(object["plays"])), likesCount: Int64(number(object["likes"])), createdAt: Int64(number(object["created"])))
    }

    private func load() {
        guard let data = try? Data(contentsOf: self.file), let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return
        }
        self.liked = (root["liked"] as? [[String: Any]] ?? []).map { Liked(track: MokoMusicLibrary.track($0), at: Int64(MokoMusicLibrary.number($0["at"]))) }
        self.history = (root["history"] as? [[String: Any]] ?? []).map { o in
            Listen(id: MokoMusicLibrary.string(o["id"]), artistId: MokoMusicLibrary.string(o["aid"]), genre: MokoMusicLibrary.string(o["genre"]), tags: o["tags"] as? [String] ?? [], durationMs: Int(MokoMusicLibrary.number(o["dur"])), listenedMs: Int(MokoMusicLibrary.number(o["l"])), finished: (o["fin"] as? Bool) ?? false, at: Int64(MokoMusicLibrary.number(o["at"])))
        }
    }

    private func save() {
        let liked: [[String: Any]] = self.liked.map { item in
            var object = MokoMusicLibrary.json(item.track)
            object["at"] = Double(item.at)
            return object
        }
        let history: [[String: Any]] = self.history.map { h in
            ["id": h.id, "aid": h.artistId, "genre": h.genre, "tags": h.tags, "dur": h.durationMs, "l": h.listenedMs, "fin": h.finished, "at": Double(h.at)]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: ["liked": liked, "history": history]) else {
            return
        }
        try? FileManager.default.createDirectory(at: self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: self.file, options: .atomic)
    }

    public func isLiked(_ id: String) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.liked.contains { $0.track.id == id }
    }

    public func setLiked(_ track: MokoMusicTrack, _ liked: Bool) {
        self.lock.lock()
        let index = self.liked.firstIndex { $0.track.id == track.id }
        if liked && index == nil {
            var copy = track
            copy.transcodingUrl = ""
            copy.authorization = ""
            self.liked.insert(Liked(track: copy, at: self.nowSeconds), at: 0)
        } else if !liked, let index {
            self.liked.remove(at: index)
        } else {
            self.lock.unlock()
            return
        }
        self.save()
        self.lock.unlock()
        self.changedPipe.putNext(Void())
    }

    public func likedTracks() -> [MokoMusicTrack] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.liked.map(\.track)
    }

    public func recordListen(_ track: MokoMusicTrack, listenedMs: Int, finished: Bool) {
        guard !track.id.isEmpty, track.durationMs > 0 else {
            return
        }
        self.lock.lock()
        self.history.append(Listen(id: track.id, artistId: track.artistId, genre: track.genre, tags: track.tags, durationMs: track.durationMs, listenedMs: min(max(listenedMs, 0), track.durationMs), finished: finished, at: self.nowSeconds))
        if self.history.count > MokoMusicLibrary.historyLimit {
            self.history.removeFirst(self.history.count - MokoMusicLibrary.historyLimit)
        }
        self.save()
        self.lock.unlock()
    }

    public var hasTaste: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return !self.liked.isEmpty || !self.history.isEmpty
    }

    func snapshot() -> (liked: [Liked], history: [Listen]) {
        self.lock.lock()
        defer { self.lock.unlock() }
        return (self.liked, self.history)
    }
}
