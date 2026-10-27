import Foundation

public enum MokoQueueOrder: Equatable {
    case regular
    case reversed
    case random
}

public enum MokoQueueLooping: Equatable {
    case none
    case all
    /// Repeating one track is done by the app player itself; the queue only moves on request.
    case item
}

public enum MokoQueueStepReason: Equatable {
    /// "Next"/"Previous" pressed.
    case user
    /// The current track played to its end; `autoplay` is the `player.autoplay_next` setting.
    case trackEnded(autoplay: Bool)
}

/// The play order of a SoundCloud queue. Tracks that failed to download are skipped.
public struct MokoMusicQueue: Equatable {
    public private(set) var tracks: [MokoMusicTrack]
    public private(set) var index: Int?
    public var order: MokoQueueOrder = .regular
    public var looping: MokoQueueLooping = .none
    private var failed: Set<String> = []

    public init(tracks: [MokoMusicTrack], startIndex: Int) {
        self.tracks = tracks
        self.index = tracks.indices.contains(startIndex) ? startIndex : nil
    }

    public var current: MokoMusicTrack? {
        return self.index.map { self.tracks[$0] }
    }

    private func playable(_ index: Int) -> Bool {
        return !self.failed.contains(self.tracks[index].id)
    }

    /// Moves `delta` (+1 next, -1 previous) and returns the new index, or nil when playback should stop.
    /// `random` returns a number in `0..<upperBound`.
    public mutating func step(_ delta: Int, reason: MokoQueueStepReason, random: (Int) -> Int) -> Int? {
        guard let index = self.index, !self.tracks.isEmpty else {
            return nil
        }
        if case .trackEnded(autoplay: false) = reason {
            self.index = nil
            return nil
        }
        let candidates = self.tracks.indices.filter { self.playable($0) }
        if candidates.isEmpty {
            self.index = nil
            return nil
        }
        if self.order == .random {
            let others = candidates.filter { $0 != index }
            let pool = others.isEmpty ? candidates : others
            let next = pool[min(max(random(pool.count), 0), pool.count - 1)]
            self.index = next
            return next
        }
        let direction = (self.order == .reversed ? -delta : delta) >= 0 ? 1 : -1
        var next = index
        for _ in 0 ..< self.tracks.count {
            next += direction
            if next >= self.tracks.count || next < 0 {
                if self.looping == .all {
                    next = direction > 0 ? 0 : self.tracks.count - 1
                } else if direction < 0 {
                    // "Previous" at the start stays on the first track, as InstantPageMediaPlaylist does.
                    let first = candidates.first!
                    self.index = first
                    return first
                } else {
                    self.index = nil
                    return nil
                }
            }
            if self.playable(next) {
                self.index = next
                return next
            }
        }
        self.index = nil
        return nil
    }

    public mutating func jump(to index: Int) {
        if self.tracks.indices.contains(index) {
            self.index = index
        }
    }

    public mutating func markFailed(_ index: Int) {
        if self.tracks.indices.contains(index) {
            self.failed.insert(self.tracks[index].id)
        }
    }

    public mutating func move(from: Int, to: Int) {
        guard self.tracks.indices.contains(from), self.tracks.indices.contains(to) else {
            return
        }
        let currentId = self.current?.id
        let track = self.tracks.remove(at: from)
        self.tracks.insert(track, at: to)
        self.index = currentId.flatMap { id in self.tracks.firstIndex(where: { $0.id == id }) }
    }

    public mutating func remove(at index: Int) {
        guard self.tracks.indices.contains(index) else {
            return
        }
        let currentId = self.current?.id
        self.tracks.remove(at: index)
        self.index = currentId.flatMap { id in self.tracks.firstIndex(where: { $0.id == id }) }
    }
}
