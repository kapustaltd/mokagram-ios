import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import MokoCore
import MokoMusic

/// The process-wide music state: one SoundCloud client, cache, library and lyrics service shared
/// by every account, as on Desktop.
public final class MokoMusicContext {
    public static let shared = MokoMusicContext()

    public let client: MokoSoundCloudClient
    public let downloader: MokoTrackDownloader
    public let library: MokoMusicLibrary
    public let lyrics: MokoLyricsService

    private let queuePromise = ValuePromise<MokoMusicQueue?>(nil, ignoreRepeated: true)
    private var nextQueueId: Int64 = 0

    private init() {
        let transport = MokoURLSessionTransport()
        let support = MokoStorage.containerURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let musicDirectory = support.appendingPathComponent("mokagram_music", isDirectory: true)
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("mokagram_music", isDirectory: true)
        self.client = MokoSoundCloudClient(transport: transport, clientIdFile: musicDirectory.appendingPathComponent("client_id.txt"))
        self.downloader = MokoTrackDownloader(client: self.client, transport: transport, cacheDirectory: caches, limitBytes: {
            return Int64(MokoSettings.int("music.cache_mb", accountId: 0)) * 1024 * 1024
        })
        self.library = MokoMusicLibrary(file: musicDirectory.appendingPathComponent("library.json"))
        self.lyrics = MokoLyricsService(transport: transport)
    }

    /// The queue that is playing now, nil when no SoundCloud queue plays.
    public var currentQueue: Signal<MokoMusicQueue?, NoError> {
        return self.queuePromise.get()
    }

    /// The SoundCloud track that is playing now, nil when no SoundCloud queue plays. The player sheet
    /// uses it to offer like / send / add-to-profile for a catalogue track.
    public private(set) var currentTrack: MokoMusicTrack?

    func updateQueue(_ queue: MokoMusicQueue?) {
        self.currentTrack = queue?.current
        self.queuePromise.set(queue)
    }

    func makeQueueId() -> Int64 {
        self.nextQueueId += 1
        return self.nextQueueId
    }

    /// Desktop's `DocumentIdForTrack`: 0x4D4F4B << 40 plus the numeric track id.
    public static func fileId(for track: MokoMusicTrack) -> Int64 {
        return fileId(forTrackId: track.id)
    }

    public static func fileId(forTrackId id: String) -> Int64 {
        let numeric = UInt64(id) ?? UInt64(truncatingIfNeeded: id.hashValue)
        return Int64(bitPattern: 0x4D4F4B0000000000 &+ numeric)
    }

    /// The downloaded track as a local audio file the app player can play.
    public func localFile(for track: MokoMusicTrack, path: String) -> TelegramMediaFile {
        let fileId = MokoMusicContext.fileId(for: track)
        if let artwork = URL(string: track.largeArtworkUrl), !track.largeArtworkUrl.isEmpty {
            MokoArtworkRegistry.register(fileId: fileId, url: artwork)
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value
        let kind = track.matchingFile(URL(fileURLWithPath: path))
        let mimeType = kind.mimeType
        return TelegramMediaFile(
            fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId),
            partialReference: nil,
            resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: fileId, size: size),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: mimeType,
            size: size,
            attributes: [
                .Audio(isVoice: false, duration: track.durationMs / 1000, title: track.title, performer: track.artist, waveform: nil),
                .FileName(fileName: "\(track.artist) - \(track.title).\(kind.fileExtension)"),
            ],
            alternativeRepresentations: []
        )
    }

    /// Plays `tracks` from `startIndex` through the app's music player.
    public func play(_ tracks: [MokoMusicTrack], startIndex: Int, context: AccountContext) {
        guard tracks.indices.contains(startIndex) else {
            return
        }
        let playlist = MokoMusicPlaylist(queue: MokoMusicQueue(tracks: tracks, startIndex: startIndex), musicContext: self, accountContext: context)
        context.sharedContext.mediaManager.setPlaylist((context, playlist), type: .music, control: .playback(.play))
    }
}
