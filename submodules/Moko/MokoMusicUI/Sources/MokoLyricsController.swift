import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import UniversalMediaPlayer
import MokoCore
import MokoMusic
import MokoSettingsUI

private struct MokoLyricLineTag: ItemListItemTag {
    let index: Int

    func isEqual(to other: ItemListItemTag) -> Bool {
        return (other as? MokoLyricLineTag)?.index == self.index
    }
}

private struct MokoPlayingTrack: Equatable {
    var title: String
    var performer: String
    var durationMs: Int64

    var cacheKey: String {
        return "\(self.title)|\(self.performer)|\(self.durationMs)"
    }
}

private struct MokoLyricsState: Equatable {
    var track: MokoPlayingTrack?
    var lyrics: MokoLyrics?
    var loading = false
    var currentLine: Int?
    /// Manual scrolling pauses following the current line until this time.
    var followPausedUntil: Double = 0
}

private final class MokoLyricsArguments {
    let seek: (Int64) -> Void

    init(seek: @escaping (Int64) -> Void) {
        self.seek = seek
    }
}

private enum MokoLyricsRow: ItemListNodeEntry {
    case header(text: String)
    case line(index: Int, text: String, timeMs: Int64, isCurrent: Bool)
    case footer(text: String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .line(index, _, _, _):
            return 10 + Int32(index)
        case .footer:
            return 1
        }
    }

    static func <(lhs: MokoLyricsRow, rhs: MokoLyricsRow) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MokoLyricsArguments
        switch self {
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .line(index, text, timeMs, isCurrent):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text.isEmpty ? "♪" : text, kind: isCurrent ? .generic : .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.seek(timeMs)
            }, tag: MokoLyricLineTag(index: index))
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// Lyrics of whatever music plays now (SoundCloud or a Telegram audio file), from LRCLIB or
/// NetEase. Synced lyrics follow the playback; a tapped line seeks to its time; scrolling by hand
/// stops the following for 3 s (Desktop `14bc7da059`, `d57848c6b0`).
public func mokoLyricsController(context: AccountContext) -> ViewController {
    let music = MokoMusicContext.shared
    let statePromise = ValuePromise(MokoLyricsState(), ignoreRepeated: true)
    let stateValue = Atomic(value: MokoLyricsState())
    let updateState: ((inout MokoLyricsState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { state in
            var state = state
            f(&state)
            return state
        })
    }
    let fetchDisposable = MetaDisposable()
    var lastStatus: MediaPlayerStatus?

    let arguments = MokoLyricsArguments(seek: { timeMs in
        context.sharedContext.mediaManager.playlistControl(.seek(Double(timeMs) / 1000.0), type: .music)
    })

    let playerDisposable = (context.sharedContext.mediaManager.musicMediaPlayerState
    |> deliverOnMainQueue).start(next: { value in
        guard let (_, state, _) = value, case let .state(itemState) = state, case let .music(title, performer, _, _, _)? = itemState.item.displayData else {
            lastStatus = nil
            return
        }
        lastStatus = itemState.status
        // Matching uses the length, so wait until the player knows it.
        guard itemState.status.duration > 0 else {
            return
        }
        let track = MokoPlayingTrack(title: title ?? "", performer: performer ?? "", durationMs: Int64(itemState.status.duration * 1000.0))
        guard track.title != stateValue.with({ $0.track?.title }) || track.performer != stateValue.with({ $0.track?.performer }) else {
            return
        }
        updateState { state in
            state.track = track
            state.lyrics = nil
            state.loading = true
            state.currentLine = nil
        }
        fetchDisposable.set((music.lyrics.fetch(cacheKey: track.cacheKey, title: track.title, artist: track.performer, durationMs: track.durationMs)
        |> deliverOnMainQueue).start(next: { lyrics in
            guard stateValue.with({ $0.track }) == track else {
                return
            }
            updateState { state in
                state.lyrics = lyrics
                state.loading = false
            }
        }))
    })

    // The player reports a status only when it changes; the position in between is extrapolated.
    let ticker = SwiftSignalKit.Timer(timeout: 0.25, repeat: true, completion: {
        guard let status = lastStatus, let lyrics = stateValue.with({ $0.lyrics }), lyrics.synced else {
            return
        }
        var position = status.timestamp
        if case .playing = status.status {
            position += (CACurrentMediaTime() - status.generationTimestamp) * status.baseRate
        }
        let line = MokoLyricsParsing.currentLine(lyrics.lines, positionMs: Int64(position * 1000.0))
        if line != stateValue.with({ $0.currentLine }) {
            updateState { $0.currentLine = line }
        }
    }, queue: .mainQueue())
    ticker.start()

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings
        var rows: [MokoLyricsRow] = []
        if let track = state.track {
            rows.append(.header(text: track.performer.isEmpty ? track.title : "\(track.performer) — \(track.title)"))
        }
        if state.track == nil {
            rows.append(.footer(text: strings.moko("Сейчас ничего не играет.")))
        } else if state.loading {
            rows.append(.footer(text: strings.moko("Ищу текст…")))
        } else if let lyrics = state.lyrics, lyrics.found {
            for (index, line) in lyrics.lines.enumerated() {
                rows.append(.line(index: index, text: line.text, timeMs: lyrics.synced ? line.timeMs : 0, isCurrent: lyrics.synced && index == state.currentLine))
            }
            if !lyrics.synced {
                rows.append(.footer(text: strings.moko("Текст без меток времени.")))
            }
        } else {
            rows.append(.footer(text: strings.moko("Текст не найден")))
        }
        let follow = CACurrentMediaTime() >= state.followPausedUntil
        let ensureVisible: ItemListItemTag? = follow ? state.currentLine.map { MokoLyricLineTag(index: $0) } : nil
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.moko("Текст песни")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: rows, style: .blocks, ensureVisibleItemTag: ensureVisible, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        fetchDisposable.dispose()
        playerDisposable.dispose()
        ticker.invalidate()
    }

    let controller = ItemListController(context: context, state: signal)
    controller.beganInteractiveDragging = {
        updateState { $0.followPausedUntil = CACurrentMediaTime() + 3.0 }
    }
    return controller
}
