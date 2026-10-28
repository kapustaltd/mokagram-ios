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

private final class MokoLyricsArguments {
    let seek: (Int64) -> Void

    init(seek: @escaping (Int64) -> Void) {
        self.seek = seek
    }
}

private enum MokoLyricsRow: ItemListNodeEntry {
    case header(text: String)
    case line(index: Int, text: String, timeMs: Int64?, isCurrent: Bool)
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
            return 1_000_000
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
            // Lines without timestamps have no time to seek to.
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: text.isEmpty ? "♪" : text, kind: isCurrent ? .generic : .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if let timeMs {
                    arguments.seek(timeMs)
                }
            }, tag: MokoLyricLineTag(index: index))
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// The full screen lyrics: the list behind the "expand" button of the lyrics card, and the long press on
/// the compact cover. A tapped line seeks to its time; scrolling by hand stops the following for 3 s
/// (Desktop `14bc7da059`, `d57848c6b0`).
public func mokoLyricsController(context: AccountContext) -> ViewController {
    let model = MokoLyricsModel(context: context)
    let followPausedUntil = ValuePromise<Double>(0.0, ignoreRepeated: true)

    let arguments = MokoLyricsArguments(seek: { timeMs in
        model.seek(toMs: timeMs)
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, model.state, followPausedUntil.get())
    |> map { presentationData, state, pausedUntil -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
                rows.append(.line(index: index, text: line.text, timeMs: lyrics.synced ? line.timeMs : nil, isCurrent: lyrics.synced && index == state.currentLine))
            }
            if !lyrics.synced {
                rows.append(.footer(text: strings.moko("Текст без меток времени.")))
            }
        } else {
            rows.append(.footer(text: strings.moko("Текст не найден")))
        }
        let follow = CACurrentMediaTime() >= pausedUntil
        let ensureVisible: ItemListItemTag? = follow ? state.currentLine.map { MokoLyricLineTag(index: $0) } : nil
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(strings.moko("Текст песни")), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: rows, style: .blocks, ensureVisibleItemTag: ensureVisible, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    // The model lives as long as the signal's subscription.
    |> afterDisposed {
        withExtendedLifetime(model) {}
    }

    let controller = ItemListController(context: context, state: signal)
    controller.beganInteractiveDragging = {
        followPausedUntil.set(CACurrentMediaTime() + 3.0)
    }
    return controller
}
