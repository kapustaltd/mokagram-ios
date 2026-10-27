import Foundation

/// A SoundCloud track, as Desktop's `Mokagram::Music::Track`.
public struct MokoMusicTrack: Codable, Hashable {
    public var id: String
    public var title: String
    public var artist: String
    /// 100x100; `largeArtworkUrl` is the 500x500 variant.
    public var artworkUrl: String
    public var permalink: String
    /// The chosen stream variant (progressive mp3 or hls).
    public var transcodingUrl: String
    public var authorization: String
    /// "mp3" or "m4a".
    public var fileExtension: String
    public var durationMs: Int
    public var isHls: Bool
    // For recommendations.
    public var artistId: String
    public var genre: String
    public var tags: [String]
    public var playbackCount: Int64
    public var likesCount: Int64
    /// Unix time.
    public var createdAt: Int64

    public init(id: String, title: String, artist: String, artworkUrl: String, permalink: String, transcodingUrl: String, authorization: String, fileExtension: String, durationMs: Int, isHls: Bool, artistId: String, genre: String, tags: [String], playbackCount: Int64, likesCount: Int64, createdAt: Int64) {
        self.id = id
        self.title = title
        self.artist = artist
        self.artworkUrl = artworkUrl
        self.permalink = permalink
        self.transcodingUrl = transcodingUrl
        self.authorization = authorization
        self.fileExtension = fileExtension
        self.durationMs = durationMs
        self.isHls = isHls
        self.artistId = artistId
        self.genre = genre
        self.tags = tags
        self.playbackCount = playbackCount
        self.likesCount = likesCount
        self.createdAt = createdAt
    }

    public var largeArtworkUrl: String {
        guard let range = self.artworkUrl.range(of: "-large", options: .backwards) else {
            return self.artworkUrl
        }
        return self.artworkUrl.replacingCharacters(in: range, with: "-t500x500")
    }
}

/// What a downloaded track file really is. A stored (liked) track keeps no stream variant, so its
/// own `fileExtension` is a guess; the file the downloader produced is authoritative.
public struct MokoTrackFileKind: Equatable {
    public let fileExtension: String
    public let mimeType: String
}

extension MokoMusicTrack {
    public func matchingFile(_ url: URL) -> MokoTrackFileKind {
        let fileExtension = url.pathExtension.isEmpty ? self.fileExtension : url.pathExtension.lowercased()
        return MokoTrackFileKind(fileExtension: fileExtension, mimeType: fileExtension == "m4a" ? "audio/mp4" : "audio/mpeg")
    }
}

/// Parses api-v2 track objects exactly as Desktop's `ParseTrack` (mokagram_soundcloud.cpp).
public enum MokoSoundCloudParser {
    private static let tagPattern = try! NSRegularExpression(pattern: "\"([^\"]+)\"|(\\S+)")

    private static func string(_ value: Any?) -> String {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return ""
    }

    private static func int64(_ value: Any?) -> Int64 {
        return (value as? NSNumber)?.int64Value ?? 0
    }

    public static func track(_ object: [String: Any]) -> MokoMusicTrack {
        let user = object["user"] as? [String: Any] ?? [:]
        var artwork = string(object["artwork_url"])
        if artwork.isEmpty {
            artwork = string(user["avatar_url"])
        }
        var tags: [String] = []
        let rawTags = string(object["tag_list"])
        for match in tagPattern.matches(in: rawTags, range: NSRange(rawTags.startIndex..., in: rawTags)) {
            let range = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            if let swiftRange = Range(range, in: rawTags), tags.count < 12 {
                let tag = rawTags[swiftRange].lowercased()
                if !tag.isEmpty {
                    tags.append(tag)
                }
            }
        }
        var progressive = ""
        var hlsMp3 = ""
        var hlsAac = ""
        let media = object["media"] as? [String: Any] ?? [:]
        for item in media["transcodings"] as? [[String: Any]] ?? [] {
            if (item["snipped"] as? Bool) == true {
                continue
            }
            let format = item["format"] as? [String: Any] ?? [:]
            let protocolName = string(format["protocol"])
            let mime = string(format["mime_type"])
            let url = string(item["url"])
            if protocolName == "progressive" && mime.contains("mpeg") {
                progressive = url
            } else if protocolName == "hls" && mime.contains("mpeg") && !mime.contains("mpegurl") {
                hlsMp3 = url
            } else if protocolName == "hls" && mime.contains("mp4") {
                hlsAac = url
            }
        }
        let (transcodingUrl, fileExtension, isHls): (String, String, Bool)
        if !progressive.isEmpty {
            (transcodingUrl, fileExtension, isHls) = (progressive, "mp3", false)
        } else if !hlsAac.isEmpty {
            (transcodingUrl, fileExtension, isHls) = (hlsAac, "m4a", true)
        } else if !hlsMp3.isEmpty {
            (transcodingUrl, fileExtension, isHls) = (hlsMp3, "mp3", true)
        } else {
            (transcodingUrl, fileExtension, isHls) = ("", "mp3", false)
        }
        let createdAt = ISO8601DateFormatter().date(from: string(object["created_at"])).map { Int64($0.timeIntervalSince1970) } ?? 0
        return MokoMusicTrack(
            id: string(object["id"]),
            title: string(object["title"]),
            artist: string(user["username"]),
            artworkUrl: artwork,
            permalink: string(object["permalink_url"]),
            transcodingUrl: transcodingUrl,
            authorization: string(object["track_authorization"]),
            fileExtension: fileExtension,
            durationMs: Int(int64(object["duration"])),
            isHls: isHls,
            artistId: string(user["id"]),
            genre: string(object["genre"]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            tags: tags,
            playbackCount: int64(object["playback_count"]),
            likesCount: int64(object["likes_count"]),
            createdAt: createdAt
        )
    }

    /// Tracks of a `collection` response that can be played, and whether there is a next page.
    public static func collection(_ data: Data) -> (tracks: [MokoMusicTrack], hasNext: Bool) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ([], false)
        }
        let tracks = (root["collection"] as? [[String: Any]] ?? []).map(track).filter { !$0.id.isEmpty && !$0.transcodingUrl.isEmpty }
        let hasNext = !(root["next_href"] as? String ?? "").isEmpty
        return (tracks, hasNext)
    }
}
