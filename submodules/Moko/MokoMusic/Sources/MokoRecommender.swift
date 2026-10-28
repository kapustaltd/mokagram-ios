import Foundation
import SwiftSignalKit

public protocol MokoRecommendationSource {
    func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
    func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
    func search(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
}

extension MokoSoundCloudClient: MokoRecommendationSource {
    public func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> {
        return (self.related(trackId: trackId, limit: limit) as Signal<[MokoMusicTrack], MokoMusicError>) |> `catch` { _ in .single([]) }
    }

    public func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> {
        return (self.userTracks(userId: userId, limit: limit) as Signal<[MokoMusicTrack], MokoMusicError>) |> `catch` { _ in .single([]) }
    }

    public func search(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> {
        return self.searchLimited(query, limit: limit) |> `catch` { _ in .single([]) }
    }
}

/// "For you", ported from Desktop's `BuildForYou` (mokagram_music_library.cpp): a decayed taste
/// profile from likes and listens, candidates from related tracks, favourite artists and top
/// genres and tags, then greedy picking with diversity penalties.
public enum MokoRecommender {
    static let halfLifeDays = 60.0

    struct Profile {
        var track: [String: Double] = [:]
        var artist: [String: Double] = [:]
        var genre: [String: Double] = [:]
        var tag: [String: Double] = [:]
        var lastFinished: [String: Int64] = [:]
    }

    private static func decay(_ at: Int64, now: Int64) -> Double {
        let days = Double(max(now - at, 0)) / 86400.0
        return pow(0.5, days / halfLifeDays)
    }

    private static func add(_ profile: inout Profile, trackId: String, artistId: String, genre: String, tags: [String], weight: Double) {
        if !trackId.isEmpty {
            profile.track[trackId, default: 0] += weight
        }
        if !artistId.isEmpty {
            profile.artist[artistId, default: 0] += weight
        }
        if !genre.isEmpty {
            profile.genre[genre, default: 0] += weight
        }
        let norm = tags.isEmpty ? 1.0 : 1.0 / Double(tags.count).squareRoot()
        for tag in tags {
            profile.tag[tag, default: 0] += weight * norm
        }
    }

    static func profile(_ library: MokoMusicLibrary) -> Profile {
        var profile = Profile()
        let now = library.nowSeconds
        let snapshot = library.snapshot()
        for item in snapshot.liked {
            let t = item.track
            add(&profile, trackId: t.id, artistId: t.artistId, genre: t.genre, tags: t.tags, weight: 3.0 * decay(item.at, now: now))
        }
        for h in snapshot.history {
            let ratio = h.durationMs > 0 ? min(1.0, Double(h.listenedMs) / Double(h.durationMs)) : 0.0
            var weight = 0.0
            if h.finished || ratio >= 0.8 {
                weight = 1.0
                profile.lastFinished[h.id] = max(profile.lastFinished[h.id] ?? 0, h.at)
            } else if ratio >= 0.35 {
                weight = 0.25
            } else if ratio < 0.25 {
                // Skipped almost at once.
                weight = -0.8
            }
            add(&profile, trackId: h.id, artistId: h.artistId, genre: h.genre, tags: h.tags, weight: weight * decay(h.at, now: now))
        }
        return profile
    }

    private static func topKeys(_ map: [String: Double], count: Int, minimum: Double) -> [String] {
        var result: [String] = []
        for (key, value) in map.sorted(by: { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }) {
            if value <= minimum || result.count >= count {
                break
            }
            result.append(key)
        }
        return result
    }

    private struct Candidate {
        var track: MokoMusicTrack
        var seedHits: Double
        var exploration: Bool
    }

    /// `random` returns a number in [0, 1).
    public static func buildForYou(library: MokoMusicLibrary, source: MokoRecommendationSource, count: Int, random: @escaping () -> Double) -> Signal<(tracks: [MokoMusicTrack], note: String), NoError> {
        guard library.hasTaste else {
            return .single(([], "Пока нечего анализировать. Поставьте сердечко нескольким трекам и послушайте музыку: подборка подстроится под вас."))
        }
        let profile = self.profile(library)
        let now = library.nowSeconds
        let randomIndex: (Int) -> Int = { upperBound in
            return min(Int(random() * Double(upperBound)), upperBound - 1)
        }

        // Seeds: the strongest track always, the rest picked at random from the top of the list.
        let ranked = profile.track.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        var seeds: [(String, Double)] = []
        if let first = ranked.first, first.value > 0 {
            seeds.append((first.key, first.value))
        }
        var pool = ranked.dropFirst().prefix(29).filter { $0.value > 0 }.map { ($0.key, $0.value) }
        for _ in 0 ..< 5 where !pool.isEmpty {
            seeds.append(pool.remove(at: randomIndex(pool.count)))
        }
        let topArtists = topKeys(profile.artist, count: 3, minimum: 0.5)
        let topGenres = topKeys(profile.genre, count: 2, minimum: 0.5)
        let topTags = topKeys(profile.tag, count: 2, minimum: 0.5)
        let maxSeed = seeds.isEmpty ? 1.0 : max(seeds[0].1, 1.0)

        var jobs: [Signal<(tracks: [MokoMusicTrack], weight: Double, exploration: Bool), NoError>] = []
        for (id, weight) in seeds {
            let w = min(max(weight / maxSeed, 0.3), 1.0)
            jobs.append(source.related(trackId: id, limit: 25) |> map { ($0, w, false) })
        }
        for artist in topArtists {
            jobs.append(source.userTracks(userId: artist, limit: 12) |> map { ($0, 0.6, false) })
        }
        for query in topGenres + topTags {
            jobs.append(source.search(query, limit: 20) |> map { ($0, 0.2, true) })
        }
        guard !jobs.isEmpty else {
            return .single(([], "Мало данных о вкусе: послушайте и полайкайте ещё несколько треков."))
        }

        return combineLatest(jobs)
        |> take(1)
        |> map { results -> (tracks: [MokoMusicTrack], note: String) in
            var candidates: [String: Candidate] = [:]
            for result in results {
                for track in result.tracks {
                    if candidates[track.id] == nil {
                        candidates[track.id] = Candidate(track: track, seedHits: 0, exploration: result.exploration)
                    }
                    candidates[track.id]!.seedHits += result.weight
                }
            }
            let snapshot = library.snapshot()
            let liked = Set(snapshot.liked.map(\.track.id))
            var scored: [(track: MokoMusicTrack, score: Double, known: Bool)] = []
            for id in candidates.keys.sorted() where !liked.contains(id) {
                let c = candidates[id]!
                let t = c.track
                var score = 1.6 * min(1.0, c.seedHits / 1.5)
                let artistAffinity = profile.artist[t.artistId] ?? 0
                score += 1.0 * tanh(artistAffinity)
                score += 0.7 * tanh(profile.genre[t.genre] ?? 0)
                var tagAffinity = 0.0
                for tag in t.tags {
                    tagAffinity += tanh(profile.tag[tag] ?? 0)
                }
                score += 0.5 * min(1.0, tagAffinity / 2.0)
                score += 0.25 * min(max(log10(Double(t.playbackCount) + 1.0) / 7.0, 0.0), 1.0)
                if t.playbackCount > 0 {
                    score += 0.2 * min(1.0, (Double(t.likesCount) / Double(t.playbackCount)) * 25.0)
                }
                if t.createdAt > 0 && (now - t.createdAt) < 365 * 86400 {
                    score += 0.15
                }
                if artistAffinity < -0.8 {
                    score -= 2.0
                }
                if library.shownRecently.contains(id) {
                    // Was in the previous picks.
                    score -= 1.6
                }
                if let last = profile.lastFinished[id], now - last < 7 * 86400 {
                    score -= 1.5
                }
                if (profile.track[id] ?? 0) < -0.5 {
                    // Already skipped this track.
                    score -= 2.0
                }
                scored.append((t, score, artistAffinity > 0.3))
            }
            if scored.isEmpty {
                return ([], "Не нашлось подходящих треков. Попробуйте позже.")
            }

            // Greedy picking: penalties for repeating an artist or genre, about 30% new.
            var result: [MokoMusicTrack] = []
            var artistCount: [String: Int] = [:]
            var genreCount: [String: Int] = [:]
            var titles: Set<String> = []
            var unknown = 0
            while result.count < count && !scored.isEmpty {
                var best = 0
                var bestValue = -1e9
                for (index, c) in scored.enumerated() {
                    var value = c.score
                    value -= 0.55 * Double(artistCount[c.track.artistId] ?? 0)
                    if !result.isEmpty && (genreCount[c.track.genre] ?? 0) > result.count / 2 + 1 {
                        value -= 0.3
                    }
                    if !c.known && unknown < Int(Double(count) * 0.3) {
                        value += 0.3
                    }
                    if let last = result.last, last.artistId == c.track.artistId {
                        value -= 0.6
                    }
                    value += (random() - 0.5) * 0.3
                    if value > bestValue {
                        bestValue = value
                        best = index
                    }
                }
                let picked = scored.remove(at: best)
                let key = picked.track.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !titles.insert(key).inserted {
                    continue
                }
                artistCount[picked.track.artistId, default: 0] += 1
                genreCount[picked.track.genre, default: 0] += 1
                unknown += picked.known ? 0 : 1
                result.append(picked.track)
            }
            // A little of the familiar: a couple of liked tracks inside the picks.
            if snapshot.liked.count >= 5 && result.count > 6 {
                for position in [2, 8, 16] where position < result.count {
                    let pick = snapshot.liked[randomIndex(snapshot.liked.count)].track
                    if !result.contains(where: { $0.id == pick.id }) {
                        result.insert(pick, at: position)
                    }
                }
            }
            for track in result {
                library.shownRecently.insert(track.id)
            }
            if library.shownRecently.count > 300 {
                library.shownRecently.removeAll()
            }
            return (result, "")
        }
    }
}
