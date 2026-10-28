import Foundation

/// What Saveinator is asked to download. Mirrors Desktop's `Choice { media, maxHeight }`.
public struct MokoSaveinatorChoice: Equatable {
    /// "auto", "video", "audio" or "photos".
    public var media: String
    /// 0 means the best available.
    public var maxHeight: Int

    public init(media: String, maxHeight: Int) {
        self.media = media
        self.maxHeight = maxHeight
    }

    private static let mediaValues = ["auto", "video", "audio", "photos"]
    private static let heightValues = [0, 1080, 720, 480, 360]

    /// `media` is an index into auto/video/audio/photos, `quality` into best/1080/720/480/360.
    /// The height only applies when the media can contain video.
    public static func make(media: Int, quality: Int) -> MokoSaveinatorChoice {
        let media = min(max(media, 0), mediaValues.count - 1)
        let quality = min(max(quality, 0), heightValues.count - 1)
        return MokoSaveinatorChoice(media: mediaValues[media], maxHeight: mediaHasVideo(media) ? heightValues[quality] : 0)
    }

    public static func mediaHasVideo(_ media: Int) -> Bool {
        return media == 0 || media == 1
    }
}

/// Links Saveinator can download, as on Desktop (`SupportedHost`, `Normalized`, `PlatformName`).
public enum MokoSaveinatorLink {
    private static let hosts = [
        "youtube.com", "youtu.be", "tiktok.com", "x.com",
        "twitter.com", "instagram.com", "instagr.am",
        "reddit.com", "redd.it", "pin.it", "spotify.com",
        "soundcloud.com", "vk.com", "vk.ru", "vkontakte.ru",
        "twitch.tv",
    ]

    private static func matches(_ host: String, _ known: String) -> Bool {
        return host == known || host.hasSuffix("." + known)
    }

    public static func isSupportedHost(_ host: String) -> Bool {
        for known in hosts where matches(host, known) {
            return true
        }
        return host.hasPrefix("music.yandex.") || host.split(separator: ".", omittingEmptySubsequences: false).contains("pinterest")
    }

    /// The link to hand to Saveinator, or nil when `text` is not a link to a supported service.
    /// Trailing punctuation is dropped and a missing scheme becomes https.
    public static func normalized(_ text: String) -> String? {
        var link = text
        while let last = link.last, ".,;:!?)]}".contains(last) {
            link.removeLast()
        }
        guard !link.isEmpty else {
            return nil
        }
        if !link.contains("://") {
            link = "https://" + link
        }
        guard let components = URLComponents(string: link), let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http", let host = components.host?.lowercased(), !host.isEmpty, isSupportedHost(host) else {
            return nil
        }
        return link
    }

    /// The offer is made only when the whole message (trimmed) is one supported link.
    public static func loneLink(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return nil
        }
        return normalized(trimmed)
    }

    public static func host(of link: String) -> String {
        var host = URLComponents(string: link)?.host?.lowercased() ?? ""
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    public enum Platform: Equatable {
        case youtube, tiktok, x, instagram, reddit, pinterest, vk, twitch, spotify, soundcloud, yandexMusic
    }

    public static func platform(host: String) -> Platform? {
        func isAny(_ known: [String]) -> Bool {
            return known.contains { matches(host, $0) }
        }
        if isAny(["youtube.com", "youtu.be"]) {
            return .youtube
        } else if isAny(["tiktok.com"]) {
            return .tiktok
        } else if isAny(["x.com", "twitter.com"]) {
            return .x
        } else if isAny(["instagram.com", "instagr.am"]) {
            return .instagram
        } else if isAny(["reddit.com", "redd.it"]) {
            return .reddit
        } else if isAny(["pin.it"]) || host.split(separator: ".", omittingEmptySubsequences: false).contains("pinterest") {
            return .pinterest
        } else if isAny(["vk.com", "vk.ru", "vkontakte.ru"]) {
            return .vk
        } else if isAny(["twitch.tv"]) {
            return .twitch
        } else if isAny(["spotify.com"]) {
            return .spotify
        } else if isAny(["soundcloud.com"]) {
            return .soundcloud
        } else if host.hasPrefix("music.yandex.") {
            return .yandexMusic
        }
        return nil
    }

    /// Brand name; Yandex Music is the Russian key of the string table.
    public static func platformTitle(_ platform: Platform) -> String {
        switch platform {
        case .youtube: return "YouTube"
        case .tiktok: return "TikTok"
        case .x: return "X"
        case .instagram: return "Instagram"
        case .reddit: return "Reddit"
        case .pinterest: return "Pinterest"
        case .vk: return "VK"
        case .twitch: return "Twitch"
        case .spotify: return "Spotify"
        case .soundcloud: return "SoundCloud"
        case .yandexMusic: return "Яндекс Музыка"
        }
    }

    public static func isMusicLink(_ link: String) -> Bool {
        guard let components = URLComponents(string: link) else {
            return false
        }
        let host = (components.host ?? "").lowercased()
        if matches(host, "spotify.com") || matches(host, "soundcloud.com") || host.hasPrefix("music.yandex.") {
            return true
        }
        return (matches(host, "vk.com") || matches(host, "vk.ru") || matches(host, "vkontakte.ru")) && components.path.hasPrefix("/audio")
    }

    /// Indices (0 auto, 1 video, 2 audio, 3 photos) the choice sheet offers for this link.
    public static func availableMedia(for link: String) -> [Int] {
        if isMusicLink(link) {
            return [2]
        }
        switch platform(host: host(of: link)) {
        case .youtube?, .twitch?, .vk?:
            return [1, 2]
        default:
            return [0, 1, 2, 3]
        }
    }
}
