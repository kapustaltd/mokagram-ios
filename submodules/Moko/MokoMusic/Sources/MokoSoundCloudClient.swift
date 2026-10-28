import Foundation
import SwiftSignalKit

public struct MokoSearchPage: Equatable {
    public var tracks: [MokoMusicTrack]
    /// Nil when there are no more results.
    public var nextOffset: Int?

    public init(tracks: [MokoMusicTrack], nextOffset: Int?) {
        self.tracks = tracks
        self.nextOffset = nextOffset
    }
}

/// SoundCloud's unofficial api-v2, as Desktop's mokagram_soundcloud.cpp: the `client_id` is taken
/// from the site's public scripts, cached in a file and refreshed once when the API answers 401/403.
public final class MokoSoundCloudClient {
    static let api = "https://api-v2.soundcloud.com"
    static let home = URL(string: "https://soundcloud.com/")!
    static let pageSize = 20
    private static let scriptPattern = try! NSRegularExpression(pattern: "https://a-v2\\.sndcdn\\.com/assets/[^\"']+\\.js")
    private static let clientIdPattern = try! NSRegularExpression(pattern: "client_id:\"([A-Za-z0-9]{32})\"")

    private let transport: MokoHTTPTransport
    private let clientIdFile: URL
    private let clientId = Atomic<String?>(value: nil)

    public init(transport: MokoHTTPTransport, clientIdFile: URL) {
        self.transport = transport
        self.clientIdFile = clientIdFile
        if let stored = try? String(contentsOf: clientIdFile, encoding: .utf8), !stored.isEmpty {
            let _ = self.clientId.swap(stored.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static func matches(_ pattern: NSRegularExpression, in text: String, group: Int) -> [String] {
        return pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            Range(match.range(at: group), in: text).map { String(text[$0]) }
        }
    }

    /// Looks through the home page's scripts from the last one, where the id usually is.
    private func fetchClientId() -> Signal<String, MokoMusicError> {
        let transport = self.transport
        return transport.get(MokoSoundCloudClient.home, headers: [:])
        |> mapToSignal { response -> Signal<String, MokoMusicError> in
            let html = String(data: response.data, encoding: .utf8) ?? ""
            let scripts = Array(MokoSoundCloudClient.matches(MokoSoundCloudClient.scriptPattern, in: html, group: 0).reversed()).compactMap(URL.init(string:))
            func attempt(_ index: Int) -> Signal<String, MokoMusicError> {
                guard index < scripts.count else {
                    return .fail(.noClientId)
                }
                return transport.get(scripts[index], headers: [:])
                |> mapToSignal { script -> Signal<String, MokoMusicError> in
                    let text = String(data: script.data, encoding: .utf8) ?? ""
                    if let id = MokoSoundCloudClient.matches(MokoSoundCloudClient.clientIdPattern, in: text, group: 1).first {
                        return .single(id)
                    }
                    return attempt(index + 1)
                }
            }
            return attempt(0)
        }
        |> `catch` { _ -> Signal<String, MokoMusicError> in
            return .fail(.noClientId)
        }
    }

    private func ensureClientId(force: Bool) -> Signal<String, MokoMusicError> {
        if !force, let id = self.clientId.with({ $0 }) {
            return .single(id)
        }
        return self.fetchClientId()
        // Strong captures: the signals are finite and the client does not keep them, so there is no
        // cycle, and a caller may drop the client while its request is in flight.
        |> map { id -> String in
            let _ = self.clientId.swap(id)
            try? FileManager.default.createDirectory(at: self.clientIdFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? id.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
            return id
        }
    }

    /// GET with `client_id` added; on 401/403 the id is refreshed and the request repeated once.
    func apiGet(_ url: URL, query: [URLQueryItem]) -> Signal<Data, MokoMusicError> {
        return self.apiGet(url, query: query, retry: true)
    }

    private func apiGet(_ url: URL, query: [URLQueryItem], retry: Bool) -> Signal<Data, MokoMusicError> {
        let transport = self.transport
        return self.ensureClientId(force: !retry)
        |> mapToSignal { id -> Signal<Data, MokoMusicError> in
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = (components.queryItems ?? []) + query + [URLQueryItem(name: "client_id", value: id)]
            guard let requestUrl = components.url else {
                return .fail(.network(status: 0))
            }
            return transport.get(requestUrl, headers: [:])
            |> mapToSignal { response -> Signal<Data, MokoMusicError> in
                if response.status == 401 || response.status == 403 {
                    guard retry else {
                        return .fail(.clientIdExpired)
                    }
                    return self.apiGet(url, query: query, retry: false)
                }
                if response.status >= 400 {
                    return .fail(.network(status: response.status))
                }
                return .single(response.data)
            }
        }
    }

    private func collection(_ path: String, query: [URLQueryItem]) -> Signal<[MokoMusicTrack], MokoMusicError> {
        return self.apiGet(URL(string: MokoSoundCloudClient.api + path)!, query: query)
        |> map { data in
            return MokoSoundCloudParser.collection(data).tracks
        }
    }

    public func search(_ query: String, offset: Int) -> Signal<MokoSearchPage, MokoMusicError> {
        let items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(MokoSoundCloudClient.pageSize)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
        ]
        return self.apiGet(URL(string: MokoSoundCloudClient.api + "/search/tracks")!, query: items)
        |> map { data in
            let page = MokoSoundCloudParser.collection(data)
            return MokoSearchPage(tracks: page.tracks, nextOffset: page.hasNext ? offset + MokoSoundCloudClient.pageSize : nil)
        }
    }

    public func searchLimited(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError> {
        return self.collection("/search/tracks", query: [URLQueryItem(name: "q", value: query), URLQueryItem(name: "limit", value: "\(limit)")])
    }

    /// Fresh stream links by id (stored likes outlive their short-lived links).
    public func resolve(_ track: MokoMusicTrack) -> Signal<MokoMusicTrack, MokoMusicError> {
        return self.apiGet(URL(string: MokoSoundCloudClient.api + "/tracks/\(track.id)")!, query: [])
        |> mapToSignal { data -> Signal<MokoMusicTrack, MokoMusicError> in
            guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                return .fail(.unavailable)
            }
            let fresh = MokoSoundCloudParser.track(object)
            return fresh.transcodingUrl.isEmpty ? .fail(.unavailable) : .single(fresh)
        }
    }

    public func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError> {
        return self.collection("/tracks/\(trackId)/related", query: [URLQueryItem(name: "limit", value: "\(limit)")])
    }

    public func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError> {
        return self.collection("/users/\(userId)/tracks", query: [URLQueryItem(name: "limit", value: "\(limit)")])
    }
}
