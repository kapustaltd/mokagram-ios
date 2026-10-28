import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext
import MusicAlbumArtResources
import UndoUI
import MokoCore
import MokoMusic
import MokoSettingsUI

struct MokoMusicPlaylistId: SharedMediaPlaylistId {
    let queueId: Int64

    func isEqual(to: SharedMediaPlaylistId) -> Bool {
        return (to as? MokoMusicPlaylistId)?.queueId == self.queueId
    }
}

extension MokoMusicContext {
    /// The catalogue track an item of the app player is, nil for any other audio. The player sheet
    /// uses it to offer like / send / add-to-profile for catalogue tracks only.
    public func catalogueTrack(for itemId: SharedMediaPlaylistItemId?) -> MokoMusicTrack? {
        guard let itemId = itemId as? MokoMusicPlaylistItemId, let track = self.currentTrack, track.id == itemId.trackId else {
            return nil
        }
        return track
    }
}

struct MokoMusicPlaylistItemId: SharedMediaPlaylistItemId {
    let trackId: String

    func isEqual(to: SharedMediaPlaylistItemId) -> Bool {
        return (to as? MokoMusicPlaylistItemId)?.trackId == self.trackId
    }
}

final class MokoMusicPlaylistItem: SharedMediaPlaylistItem {
    let track: MokoMusicTrack
    let file: TelegramMediaFile

    init(track: MokoMusicTrack, file: TelegramMediaFile) {
        self.track = track
        self.file = file
    }

    var stableId: AnyHashable {
        return self.track.id
    }

    var id: SharedMediaPlaylistItemId {
        return MokoMusicPlaylistItemId(trackId: self.track.id)
    }

    var playbackData: SharedMediaPlaybackData? {
        return SharedMediaPlaybackData(type: .music, source: .telegramFile(reference: .standalone(media: self.file), isCopyProtected: false, isViewOnce: false))
    }

    var displayData: SharedMediaPlaybackDisplayData? {
        let reference = FileMediaReference.standalone(media: self.file)
        let albumArt = SharedMediaPlaybackAlbumArt(
            thumbnailResource: ExternalMusicAlbumArtResource(file: reference, title: self.track.title, performer: self.track.artist, isThumbnail: true),
            fullSizeResource: ExternalMusicAlbumArtResource(file: reference, title: self.track.title, performer: self.track.artist, isThumbnail: false)
        )
        return .music(title: self.track.title, performer: self.track.artist, albumArt: albumArt, long: self.track.durationMs > 10 * 60 * 1000, caption: nil)
    }
}

/// A SoundCloud queue for the app's `SharedMediaPlayer`, shaped like `InstantPageMediaPlaylist`.
/// A track is downloaded before it plays (as on Desktop) and the next one is prefetched; a track
/// that fails to download is skipped with a toast.
public final class MokoMusicPlaylist: SharedMediaPlaylist {
    private let musicContext: MokoMusicContext
    private let accountContext: AccountContext
    private var queue: MokoMusicQueue
    private let queueId: Int64

    public let id: SharedMediaPlaylistId
    public private(set) var looping: MusicPlaybackSettingsLooping = .none
    public var currentItemDisappeared: (() -> Void)?

    private let stateValue = Promise<SharedMediaPlaylistState>()
    public var state: Signal<SharedMediaPlaylistState, NoError> {
        return self.stateValue.get()
    }

    private var order: MusicPlaybackSettingsOrder = .regular
    private var currentItem: MokoMusicPlaylistItem?
    private var loading = false
    private var playedToEnd = false
    private let downloadDisposable = MetaDisposable()
    private let prefetchDisposable = MetaDisposable()
    private var statusDisposable: Disposable?
    /// Position and length of the playing track, from the player's status, in seconds.
    private var playingStatus: (trackId: String, timestamp: Double, duration: Double)?
    private var lastRecorded: String?

    init(queue: MokoMusicQueue, musicContext: MokoMusicContext, accountContext: AccountContext) {
        assert(Queue.mainQueue().isCurrent())
        self.queue = queue
        self.musicContext = musicContext
        self.accountContext = accountContext
        self.queueId = musicContext.makeQueueId()
        self.id = MokoMusicPlaylistId(queueId: self.queueId)

        self.statusDisposable = (accountContext.sharedContext.mediaManager.musicMediaPlayerState
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self, let (_, state, _) = value, case let .state(itemState) = state, let itemId = itemState.item.id as? MokoMusicPlaylistItemId else {
                return
            }
            self.playingStatus = (itemId.trackId, itemState.status.timestamp, itemState.status.duration)
        })
        self.loadCurrent()
    }

    deinit {
        self.downloadDisposable.dispose()
        self.prefetchDisposable.dispose()
        self.statusDisposable?.dispose()
    }

    public var location: SharedMediaPlaylistLocation {
        let tracks: [(index: Int, file: TelegramMediaFile)] = self.queue.tracks.enumerated().map { index, track in
            let path = self.musicContext.downloader.cachedFile(for: track)?.path ?? ""
            return (index, self.musicContext.localFile(for: track, path: path))
        }
        return MokoMusicPlaylistLocation(queueId: self.queueId, tracks: tracks, currentIndex: self.queue.index, jump: { [weak self] index in
            guard let self else {
                return
            }
            self.recordCurrentListen()
            self.queue.jump(to: index)
            self.loadCurrent()
            // Not routed through SharedMediaPlayer.control, so nothing schedules playback otherwise.
            self.accountContext.sharedContext.mediaManager.playlistControl(.playback(.play), type: .music)
        })
    }

    private var isAtEndOfCurrentTrack: Bool {
        guard let status = self.playingStatus, status.trackId == self.currentItem?.track.id, status.duration > 0 else {
            return false
        }
        return status.timestamp >= status.duration - 1.0
    }

    /// Records how much of the current track was heard (likes, history and "For you").
    private func recordCurrentListen() {
        guard let track = self.currentItem?.track, self.lastRecorded != track.id else {
            return
        }
        self.lastRecorded = track.id
        var listenedMs = 0
        if let status = self.playingStatus, status.trackId == track.id {
            listenedMs = Int(status.timestamp * 1000.0)
        }
        self.musicContext.library.recordListen(track, listenedMs: listenedMs, finished: self.isAtEndOfCurrentTrack)
    }

    public func control(_ action: SharedMediaPlaylistControlAction) {
        assert(Queue.mainQueue().isCurrent())
        let reason: MokoQueueStepReason = self.isAtEndOfCurrentTrack ? .trackEnded(autoplay: MokoSettings.bool("player.autoplay_next", accountId: 0)) : .user
        self.recordCurrentListen()
        let delta: Int
        switch action {
        case .next:
            delta = 1
        case .previous:
            delta = -1
        }
        if self.queue.step(delta, reason: reason, random: { Int.random(in: 0 ..< max($0, 1)) }) == nil {
            self.downloadDisposable.set(nil)
            self.currentItem = nil
            self.loading = false
            self.playedToEnd = true
            self.updateState()
            return
        }
        self.loadCurrent()
    }

    private func loadCurrent() {
        guard let track = self.queue.current else {
            self.currentItem = nil
            self.playedToEnd = true
            self.updateState()
            return
        }
        self.playedToEnd = false
        self.lastRecorded = nil
        if let cached = self.musicContext.downloader.cachedFile(for: track) {
            self.currentItem = MokoMusicPlaylistItem(track: track, file: self.musicContext.localFile(for: track, path: cached.path))
            self.loading = false
            self.updateState()
            return
        }
        self.currentItem = nil
        self.loading = true
        self.updateState()
        self.downloadDisposable.set((self.musicContext.downloader.download(track)
        |> deliverOnMainQueue).start(next: { [weak self] url in
            guard let self, self.queue.current?.id == track.id else {
                return
            }
            self.currentItem = MokoMusicPlaylistItem(track: track, file: self.musicContext.localFile(for: track, path: url.path))
            self.loading = false
            self.updateState()
        }, error: { [weak self] _ in
            guard let self, let index = self.queue.index, self.queue.current?.id == track.id else {
                return
            }
            self.showToast(self.accountContext.sharedContext.currentPresentationData.with { $0 }.strings.moko("Трек недоступен, переключаю дальше"))
            self.queue.markFailed(index)
            if self.queue.step(1, reason: .user, random: { Int.random(in: 0 ..< max($0, 1)) }) == nil {
                self.currentItem = nil
                self.loading = false
                self.playedToEnd = true
                self.updateState()
            } else {
                self.loadCurrent()
            }
        }))
    }

    private func showToast(_ text: String) {
        let presentationData = self.accountContext.sharedContext.currentPresentationData.with { $0 }
        self.accountContext.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), on: .root, blockInteraction: false, completion: {})
    }

    public func setOrder(_ order: MusicPlaybackSettingsOrder) {
        guard self.order != order else {
            return
        }
        self.order = order
        switch order {
        case .regular:
            self.queue.order = .regular
        case .reversed:
            self.queue.order = .reversed
        case .random:
            self.queue.order = .random
        }
        self.updateState()
    }

    public func setLooping(_ looping: MusicPlaybackSettingsLooping) {
        guard self.looping != looping else {
            return
        }
        self.looping = looping
        switch looping {
        case .none:
            self.queue.looping = .none
        case .all:
            self.queue.looping = .all
        case .item:
            self.queue.looping = .item
        }
        self.updateState()
    }

    private func updateState() {
        self.musicContext.updateQueue(self.playedToEnd ? nil : self.queue)
        self.stateValue.set(.single(SharedMediaPlaylistState(loading: self.loading, playedToEnd: self.playedToEnd, item: self.currentItem, nextItem: nil, previousItem: nil, order: self.order, looping: self.looping)))
    }

    /// Prefetches the track after the one that just started.
    public func onItemPlaybackStarted(_ item: SharedMediaPlaylistItem) {
        guard let index = self.queue.index, index + 1 < self.queue.tracks.count else {
            return
        }
        let next = self.queue.tracks[index + 1]
        if self.musicContext.downloader.cachedFile(for: next) == nil {
            self.prefetchDisposable.set(self.musicContext.downloader.download(next).start())
        }
    }
}
