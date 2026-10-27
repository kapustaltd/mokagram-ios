import Foundation
import SwiftSignalKit

public struct MokoLyricLine: Equatable {
    public var timeMs: Int64
    public var text: String

    public init(timeMs: Int64, text: String) {
        self.timeMs = timeMs
        self.text = text
    }
}

public struct MokoLyrics: Equatable {
    public var lines: [MokoLyricLine]
    public var synced: Bool
    public var found: Bool

    public init(lines: [MokoLyricLine], synced: Bool, found: Bool) {
        self.lines = lines
        self.synced = synced
        self.found = found
    }

    public static let none = MokoLyrics(lines: [], synced: false, found: false)
}

/// Desktop's lyrics parsing and matching (mokagram_lyrics.cpp), function for function.
public enum MokoLyricsParsing {
    private static let stamp = try! NSRegularExpression(pattern: "\\[(\\d+):(\\d+)(?:[.:](\\d+))?\\]")
    private static let brackets = try! NSRegularExpression(pattern: "\\s*[\\(\\[][^\\)\\]]*[\\)\\]]")
    private static let anyBracketStamp = try! NSRegularExpression(pattern: "\\[[^\\]]*\\]")
    private static let fileExtension = try! NSRegularExpression(pattern: "\\.(mp3|m4a|flac|ogg|oga|opus|wav|aac|aiff|aif|wma|alac)$", options: .caseInsensitive)
    private static let tail = try! NSRegularExpression(pattern: "\\s*[\\(\\[][^\\)\\]]*(official|video|audio|lyrics|clip|прем|клип|visualizer|hd|4k)[^\\)\\]]*[\\)\\]]", options: .caseInsensitive)

    private static func removing(_ pattern: NSRegularExpression, from text: String) -> String {
        return pattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    private static func simplified(_ text: String) -> String {
        return text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    public static func parseLrc(_ text: String) -> MokoLyrics {
        var lines: [MokoLyricLine] = []
        for raw in text.components(separatedBy: "\n") {
            let matches = stamp.matches(in: raw, range: NSRange(raw.startIndex..., in: raw))
            guard let last = matches.last else {
                continue
            }
            let line = String(raw[Range(last.range, in: raw)!.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            for match in matches {
                let group: (Int) -> String = { index in
                    Range(match.range(at: index), in: raw).map { String(raw[$0]) } ?? ""
                }
                let fraction = group(3)
                let padded = (fraction + "000").prefix(3)
                let ms = fraction.isEmpty ? 0 : (Int64(padded) ?? 0)
                lines.append(MokoLyricLine(timeMs: (Int64(group(1)) ?? 0) * 60000 + (Int64(group(2)) ?? 0) * 1000 + ms, text: line))
            }
        }
        let sorted = lines.enumerated().sorted { lhs, rhs in
            lhs.element.timeMs != rhs.element.timeMs ? lhs.element.timeMs < rhs.element.timeMs : lhs.offset < rhs.offset
        }.map(\.element)
        return MokoLyrics(lines: sorted, synced: !sorted.isEmpty, found: !sorted.isEmpty)
    }

    /// Sped-up and slowed versions: stretch the timestamps by the ratio of the lengths.
    public static func scaleTimes(_ lyrics: MokoLyrics, ratio: Double) -> MokoLyrics {
        guard abs(ratio - 1.0) >= 0.01 else {
            return lyrics
        }
        var result = lyrics
        result.lines = lyrics.lines.map { MokoLyricLine(timeMs: Int64(Double($0.timeMs) * ratio), text: $0.text) }
        return result
    }

    public static func parsePlain(_ text: String) -> MokoLyrics {
        let lines = text.components(separatedBy: "\n").map { MokoLyricLine(timeMs: 0, text: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return MokoLyrics(lines: lines, synced: false, found: !lines.isEmpty)
    }

    /// A title without any brackets: marks like "(slowed + reverb)" hurt the search most.
    public static func withoutBrackets(_ text: String) -> String {
        let result = removing(brackets, from: text).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? text : result
    }

    /// A title without tails like "(Official Video)" and without the artist's name in front.
    public static func cleanTitle(_ title: String, artist: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        result = removing(fileExtension, from: result)
        result = result.replacingOccurrences(of: "_", with: " ")
        result = removing(tail, from: result)
        let prefix = artist.trimmingCharacters(in: .whitespacesAndNewlines) + " - "
        if !artist.isEmpty, result.lowercased().hasPrefix(prefix.lowercased()) {
            result = String(result.dropFirst(prefix.count))
        }
        return simplified(result)
    }

    private static func number(_ value: Any?) -> Double {
        return (value as? NSNumber)?.doubleValue ?? 0
    }

    public static func pick(_ list: [[String: Any]], durationMs: Int64, matchingTitle: String?) -> MokoLyrics {
        var best: [String: Any]?
        var bestScore = -1e9
        var bestSynced = false
        var bestRatio = 1.0
        let duration = Double(durationMs)
        for item in list {
            let synced = item["syncedLyrics"] as? String ?? ""
            let plain = item["plainLyrics"] as? String ?? ""
            if synced.isEmpty && plain.isEmpty {
                continue
            }
            let source = number(item["duration"]) * 1000.0
            let ratio = (duration > 0 && source > 0) ? duration / source : 1.0
            let diff = abs(source - duration)
            if let matchingTitle, !matchingTitle.isEmpty {
                let title = withoutBrackets(cleanTitle(item["trackName"] as? String ?? "", artist: item["artistName"] as? String ?? ""))
                if title.caseInsensitiveCompare(matchingTitle) != .orderedSame || duration <= 0 || source <= 0 || diff > 3000 {
                    continue
                }
            }
            var useSynced = false
            var score = 10.0 - min(diff / 1000.0, 9.0)
            if !synced.isEmpty && (duration <= 0 || diff <= 12000) {
                useSynced = true
                score = 100.0 - diff / 1000.0
            } else if !synced.isEmpty && ratio > 0.5 && ratio < 2.0 {
                useSynced = true
                score = 60.0 - abs(log(ratio)) * 20.0
            }
            if score > bestScore {
                bestScore = score
                best = item
                bestSynced = useSynced
                bestRatio = ratio
            }
        }
        guard let best else {
            return .none
        }
        if bestSynced {
            let result = parseLrc(best["syncedLyrics"] as? String ?? "")
            if result.found {
                return scaleTimes(result, ratio: bestRatio)
            }
        }
        let plain = best["plainLyrics"] as? String ?? ""
        if !plain.isEmpty {
            return parsePlain(plain)
        }
        return parsePlain(removing(anyBracketStamp, from: best["syncedLyrics"] as? String ?? ""))
    }
}

/// LRCLIB with NetEase as the fallback, in Desktop's request order (`FetchLyrics`).
public final class MokoLyricsService {
    private static let credits = try! NSRegularExpression(pattern: "^\\s*(作词|作曲|编曲|制作|作詞|编曲|词|曲|Lyrics|Music|Composer|Producer|Arranger)\\s*[:：]", options: .caseInsensitive)
    private static let separator = try! NSRegularExpression(pattern: "\\s+[-–—]\\s+")
    private static let allowed: CharacterSet = {
        var set = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"))
        set.insert(charactersIn: "-._~")
        return set
    }()

    private let transport: MokoHTTPTransport
    private let cache = Atomic<[String: MokoLyrics]>(value: [:])

    public init(transport: MokoHTTPTransport) {
        self.transport = transport
    }

    /// '+' and brackets are encoded by hand: the service reads a bare '+' as a space.
    private func request(_ items: [(String, String)], durationMs: Int64, matchingTitle: String? = nil) -> Signal<MokoLyrics, NoError> {
        let query = items.map { "\($0.0)=\($0.1.addingPercentEncoding(withAllowedCharacters: MokoLyricsService.allowed) ?? "")" }.joined(separator: "&")
        guard let url = URL(string: "https://lrclib.net/api/search?" + query) else {
            return .single(.none)
        }
        return self.transport.get(url, headers: ["User-Agent": "mokaGram (https://github.com/ecronx/mokagram)"])
        |> map { response -> MokoLyrics in
            guard response.status < 400, let list = (try? JSONSerialization.jsonObject(with: response.data)) as? [[String: Any]] else {
                return .none
            }
            return MokoLyricsParsing.pick(list, durationMs: durationMs, matchingTitle: matchingTitle)
        }
        |> `catch` { _ -> Signal<MokoLyrics, NoError> in
            return .single(.none)
        }
    }

    private func neteaseJson(_ address: String) -> Signal<[String: Any], NoError> {
        guard let url = URL(string: address) else {
            return .single([:])
        }
        return self.transport.get(url, headers: ["User-Agent": "Mozilla/5.0", "Referer": "https://music.163.com/"])
        |> map { response -> [String: Any] in
            return response.status < 400 ? ((try? JSONSerialization.jsonObject(with: response.data)) as? [String: Any] ?? [:]) : [:]
        }
        |> `catch` { _ -> Signal<[String: Any], NoError> in
            return .single([:])
        }
    }

    private func requestNetease(query: String, trackName: String, durationMs: Int64) -> Signal<MokoLyrics, NoError> {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: MokoLyricsService.allowed) ?? ""
        return self.neteaseJson("https://music.163.com/api/search/get?type=1&limit=8&s=" + encoded)
        |> mapToSignal { search -> Signal<MokoLyrics, NoError> in
            let songs = (search["result"] as? [String: Any])?["songs"] as? [[String: Any]] ?? []
            var best: Int64 = 0
            var bestSource = 0.0
            var bestDiff = 1e18
            let wanted = trackName.lowercased()
            for song in songs {
                let name = (song["name"] as? String ?? "").lowercased()
                // Only a song with the same title, otherwise the words belong to someone else.
                if wanted.count >= 2 && !name.contains(wanted) && !wanted.contains(name) {
                    continue
                }
                let source = (song["duration"] as? NSNumber)?.doubleValue ?? 0
                let diff = durationMs > 0 ? abs(source - Double(durationMs)) : 0
                if diff < bestDiff {
                    bestDiff = diff
                    bestSource = source
                    best = (song["id"] as? NSNumber)?.int64Value ?? 0
                }
            }
            guard best != 0 else {
                return .single(.none)
            }
            let ratio = (durationMs > 0 && bestSource > 0) ? Double(durationMs) / bestSource : 1.0
            if durationMs > 0 && bestDiff > 12000 && (ratio <= 0.5 || ratio >= 2.0) {
                return .single(.none)
            }
            return self.neteaseJson("https://music.163.com/api/song/lyric?lv=1&kv=1&tv=-1&id=\(best)")
            |> map { lyric -> MokoLyrics in
                let text = (lyric["lrc"] as? [String: Any])?["lyric"] as? String ?? ""
                var result = text.isEmpty ? MokoLyrics.none : MokoLyricsParsing.parseLrc(text)
                result.lines = result.lines.filter { line in
                    MokoLyricsService.credits.firstMatch(in: line.text, range: NSRange(line.text.startIndex..., in: line.text)) == nil
                }
                result.found = !result.lines.isEmpty
                return result.found ? MokoLyricsParsing.scaleTimes(result, ratio: ratio) : result
            }
        }
    }

    private func requestFallback(trackName: String, artistName: String, durationMs: Int64) -> Signal<MokoLyrics, NoError> {
        let netease = {
            return self.requestNetease(query: artistName + " " + trackName, trackName: trackName, durationMs: durationMs)
        }
        if durationMs <= 0 {
            return netease()
        }
        return self.request([("track_name", trackName)], durationMs: durationMs, matchingTitle: trackName)
        |> mapToSignal { result -> Signal<MokoLyrics, NoError> in
            return result.found ? .single(result) : netease()
        }
    }

    public func fetch(cacheKey: String, title: String, artist: String, durationMs: Int64) -> Signal<MokoLyrics, NoError> {
        if let cached = self.cache.with({ $0[cacheKey] }) {
            return .single(cached)
        }
        let clean = MokoLyricsParsing.cleanTitle(title, artist: "")
        var trackName = clean
        var artistName = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        // "Artist - Title" inside the title: the uploader's name is someone else's.
        if let dash = MokoLyricsService.separator.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)), dash.range.location > 0, let range = Range(dash.range, in: clean) {
            artistName = String(clean[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            trackName = MokoLyricsParsing.cleanTitle(String(clean[range.upperBound...]), artist: artistName)
        }
        trackName = MokoLyricsParsing.withoutBrackets(trackName)
        let finalTrack = trackName
        let finalArtist = artistName
        let chain = self.request([("track_name", finalTrack), ("artist_name", finalArtist)], durationMs: durationMs)
        |> mapToSignal { first -> Signal<MokoLyrics, NoError> in
            if first.found {
                return .single(first)
            }
            return self.request([("q", finalArtist + " " + finalTrack)], durationMs: durationMs)
            |> mapToSignal { second -> Signal<MokoLyrics, NoError> in
                if second.found {
                    return .single(second)
                }
                if finalArtist == artist {
                    return self.requestFallback(trackName: finalTrack, artistName: finalArtist, durationMs: durationMs)
                }
                return self.request([("q", clean)], durationMs: durationMs)
                |> mapToSignal { third -> Signal<MokoLyrics, NoError> in
                    return third.found ? .single(third) : self.requestFallback(trackName: finalTrack, artistName: finalArtist, durationMs: durationMs)
                }
            }
        }
        // A failure is not remembered: the network may have blinked.
        return chain
        |> map { result -> MokoLyrics in
            if result.found {
                let _ = self.cache.modify { cache in
                    var cache = cache
                    cache[cacheKey] = result
                    return cache
                }
            }
            return result
        }
    }
}
