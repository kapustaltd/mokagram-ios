import Foundation
import UIKit
import SwiftSignalKit
import AccountContext
import UniversalMediaPlayer
import MokoMusic

public struct MokoPlayingTrack: Equatable {
    public var title: String
    public var performer: String
    public var durationMs: Int64

    public var cacheKey: String {
        return "\(self.title)|\(self.performer)|\(self.durationMs)"
    }
}

public struct MokoLyricsState: Equatable {
    public var track: MokoPlayingTrack?
    public var lyrics: MokoLyrics?
    public var loading = false
    public var currentLine: Int?
}

/// Lyrics of whatever music plays now (SoundCloud or a Telegram audio file), from LRCLIB or NetEase.
/// Synced lyrics follow the playback. Shared by the lyrics card of the player sheet and the full
/// screen lyrics list, so both always show the same line.
public final class MokoLyricsModel {
    private let context: AccountContext
    private let statePromise = ValuePromise(MokoLyricsState(), ignoreRepeated: true)
    private let stateValue = Atomic(value: MokoLyricsState())
    private let fetchDisposable = MetaDisposable()
    private var playerDisposable: Disposable?
    private var ticker: SwiftSignalKit.Timer?
    private var lastStatus: MediaPlayerStatus?

    public var state: Signal<MokoLyricsState, NoError> {
        return self.statePromise.get()
    }

    public var currentState: MokoLyricsState {
        return self.stateValue.with { $0 }
    }

    public init(context: AccountContext) {
        self.context = context
        let music = MokoMusicContext.shared

        self.playerDisposable = (context.sharedContext.mediaManager.musicMediaPlayerState
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            guard let (_, state, _) = value, case let .state(itemState) = state, case let .music(title, performer, _, _, _)? = itemState.item.displayData else {
                self.lastStatus = nil
                return
            }
            self.lastStatus = itemState.status
            // Matching uses the length, so wait until the player knows it.
            guard itemState.status.duration > 0 else {
                return
            }
            let track = MokoPlayingTrack(title: title ?? "", performer: performer ?? "", durationMs: Int64(itemState.status.duration * 1000.0))
            guard track.title != self.stateValue.with({ $0.track?.title }) || track.performer != self.stateValue.with({ $0.track?.performer }) else {
                return
            }
            self.updateState { state in
                state.track = track
                state.lyrics = nil
                state.loading = true
                state.currentLine = nil
            }
            self.fetchDisposable.set((music.lyrics.fetch(cacheKey: track.cacheKey, title: track.title, artist: track.performer, durationMs: track.durationMs)
            |> deliverOnMainQueue).start(next: { [weak self] lyrics in
                guard let self, self.stateValue.with({ $0.track }) == track else {
                    return
                }
                self.updateState { state in
                    state.lyrics = lyrics
                    state.loading = false
                }
            }))
        })

        // The player reports a status only when it changes; the position in between is extrapolated.
        let ticker = SwiftSignalKit.Timer(timeout: 0.25, repeat: true, completion: { [weak self] in
            guard let self, let status = self.lastStatus, let lyrics = self.stateValue.with({ $0.lyrics }), lyrics.synced else {
                return
            }
            var position = status.timestamp
            if case .playing = status.status {
                position += (CACurrentMediaTime() - status.generationTimestamp) * status.baseRate
            }
            let line = MokoLyricsParsing.currentLine(lyrics.lines, positionMs: Int64(position * 1000.0))
            if line != self.stateValue.with({ $0.currentLine }) {
                self.updateState { $0.currentLine = line }
            }
        }, queue: .mainQueue())
        self.ticker = ticker
        ticker.start()
    }

    deinit {
        self.fetchDisposable.dispose()
        self.playerDisposable?.dispose()
        self.ticker?.invalidate()
    }

    private func updateState(_ f: (inout MokoLyricsState) -> Void) {
        self.statePromise.set(self.stateValue.modify { state in
            var state = state
            f(&state)
            return state
        })
    }

    /// Seeks the playing track to a lyric line's time.
    public func seek(toMs timeMs: Int64) {
        self.context.sharedContext.mediaManager.playlistControl(.seek(Double(timeMs) / 1000.0), type: .music)
    }
}
