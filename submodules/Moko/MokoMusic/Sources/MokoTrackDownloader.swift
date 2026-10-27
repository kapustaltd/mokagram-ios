import Foundation
import SwiftSignalKit

/// Downloads SoundCloud tracks into a size-limited cache, as Desktop's `Download` /
/// `DownloadHls` (mokagram_soundcloud.cpp): progressive files in one request, HLS by
/// concatenating the init segment and the media segments in order.
public final class MokoTrackDownloader {
    private static let extensions = ["mp3", "m4a"]
    private static let mapPattern = try! NSRegularExpression(pattern: "URI=\"([^\"]+)\"")

    private let client: MokoSoundCloudClient
    private let transport: MokoHTTPTransport
    private let cacheDirectory: URL
    private let limitBytes: () -> Int64

    public init(client: MokoSoundCloudClient, transport: MokoHTTPTransport, cacheDirectory: URL, limitBytes: @escaping () -> Int64) {
        self.client = client
        self.transport = transport
        self.cacheDirectory = cacheDirectory
        self.limitBytes = limitBytes
    }

    public func cachedFile(for track: MokoMusicTrack) -> URL? {
        for fileExtension in [track.fileExtension] + MokoTrackDownloader.extensions {
            let url = self.cacheDirectory.appendingPathComponent("\(track.id).\(fileExtension)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// `EXT-X-MAP` URI first, then every non-comment line, relative to `base`.
    public static func hlsParts(playlist: String, base: URL) -> [URL] {
        var parts: [URL] = []
        for raw in playlist.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXT-X-MAP:") {
                let range = NSRange(line.startIndex..., in: line)
                if let match = mapPattern.firstMatch(in: line, range: range), let uri = Range(match.range(at: 1), in: line), let url = URL(string: String(line[uri]), relativeTo: base) {
                    parts.append(url.absoluteURL)
                }
            } else if !line.isEmpty && !line.hasPrefix("#"), let url = URL(string: line, relativeTo: base) {
                parts.append(url.absoluteURL)
            }
        }
        return parts
    }

    public func download(_ track: MokoMusicTrack) -> Signal<URL, MokoMusicError> {
        if let cached = self.cachedFile(for: track) {
            return .single(cached)
        }
        // Stream links live a short time, so a stored track is always resolved again first.
        return self.client.resolve(track)
        |> mapToSignal { fresh -> Signal<URL, MokoMusicError> in
            var query: [URLQueryItem] = []
            if !fresh.authorization.isEmpty {
                query.append(URLQueryItem(name: "track_authorization", value: fresh.authorization))
            }
            guard let transcoding = URL(string: fresh.transcodingUrl) else {
                return .fail(.unavailable)
            }
            return self.client.apiGet(transcoding, query: query)
            |> mapToSignal { data -> Signal<URL, MokoMusicError> in
                let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                guard let address = object?["url"] as? String, let stream = URL(string: address) else {
                    return .fail(.noStreamUrl)
                }
                let destination = self.cacheDirectory.appendingPathComponent("\(fresh.id).\(fresh.fileExtension)")
                let bytes: Signal<Data, MokoMusicError> = fresh.isHls ? self.downloadHls(stream) : self.downloadFile(stream)
                return bytes
                |> mapToSignal { data -> Signal<URL, MokoMusicError> in
                    return self.finish(data, destination: destination)
                }
            }
        }
    }

    private func downloadFile(_ url: URL) -> Signal<Data, MokoMusicError> {
        return self.transport.get(url, headers: [:])
        |> mapToSignal { response -> Signal<Data, MokoMusicError> in
            return response.status >= 400 ? .fail(.network(status: response.status)) : .single(response.data)
        }
    }

    private func downloadHls(_ playlist: URL) -> Signal<Data, MokoMusicError> {
        let transport = self.transport
        return transport.get(playlist, headers: [:])
        |> mapToSignal { response -> Signal<Data, MokoMusicError> in
            guard response.status < 400 else {
                return .fail(.network(status: response.status))
            }
            let parts = MokoTrackDownloader.hlsParts(playlist: String(data: response.data, encoding: .utf8) ?? "", base: response.url)
            guard !parts.isEmpty else {
                return .fail(.emptyPlaylist)
            }
            func segment(_ index: Int, _ buffer: Data) -> Signal<Data, MokoMusicError> {
                guard index < parts.count else {
                    return .single(buffer)
                }
                return transport.get(parts[index], headers: [:])
                |> mapError { _ -> MokoMusicError in
                    return .segmentFailed
                }
                |> mapToSignal { part -> Signal<Data, MokoMusicError> in
                    guard part.status < 400 else {
                        return .fail(.segmentFailed)
                    }
                    var buffer = buffer
                    buffer.append(part.data)
                    return segment(index + 1, buffer)
                }
            }
            return segment(0, Data())
        }
    }

    private func finish(_ data: Data, destination: URL) -> Signal<URL, MokoMusicError> {
        let part = destination.appendingPathExtension("part")
        do {
            try FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: part)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: part, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: part)
            return .fail(.writeFailed)
        }
        self.prune(protecting: [destination])
        return .single(destination)
    }

    private func files() -> [(url: URL, size: Int64, modified: Date)] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: keys)) ?? []
        return urls.compactMap { url in
            guard MokoTrackDownloader.extensions.contains(url.pathExtension), let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }
            return (url, Int64(values.fileSize ?? 0), values.contentModificationDate ?? .distantPast)
        }
    }

    /// Removes the oldest tracks until the cache fits `limitBytes()`, never one in `protecting`.
    public func prune(protecting: Set<URL>) {
        let protected = Set(protecting.map(\.standardizedFileURL))
        var files = self.files().sorted { $0.modified < $1.modified }
        var total = files.reduce(Int64(0)) { $0 + $1.size }
        let limit = self.limitBytes()
        while total > limit, let index = files.firstIndex(where: { !protected.contains($0.url.standardizedFileURL) }) {
            let file = files.remove(at: index)
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
        }
    }

    /// Track ids of every cached file.
    public func cachedTrackIds() -> [String] {
        return self.files().map { $0.url.deletingPathExtension().lastPathComponent }
    }

    public func clear(protecting: Set<URL>) {
        let protected = Set(protecting.map(\.standardizedFileURL))
        for file in self.files() where !protected.contains(file.url.standardizedFileURL) {
            try? FileManager.default.removeItem(at: file.url)
        }
    }
}
