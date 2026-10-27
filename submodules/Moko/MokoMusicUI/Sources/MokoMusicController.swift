import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import MokoCore
import MokoMusic
import MokoSettingsUI

private enum MokoMusicTab: Int {
    case search
    case forYou
    case likes
    case chats
}

private struct MokoMusicState: Equatable {
    var tab: MokoMusicTab = .search
    var query: String = ""
    var results: [MokoMusicTrack] = []
    var nextOffset: Int?
    var searching = false
    var error: String?
    var forYou: [MokoMusicTrack] = []
    var forYouNote = ""
    var forYouLoading = false
    var chatsQuery = ""
    var chatsResults: [EngineMessage] = []
    var chatsSearching = false
}

private final class MokoMusicArguments {
    let updateQuery: (String) -> Void
    let search: () -> Void
    let loadMore: () -> Void
    let openTrack: (MokoMusicTrack, [MokoMusicTrack], Int) -> Void
    let refreshForYou: () -> Void
    let updateChatsQuery: (String) -> Void
    let searchChats: () -> Void
    let openMessage: (EngineMessage) -> Void
    let openLyrics: () -> Void
    let artwork: (MokoMusicTrack) -> UIImage?

    init(updateQuery: @escaping (String) -> Void, search: @escaping () -> Void, loadMore: @escaping () -> Void, openTrack: @escaping (MokoMusicTrack, [MokoMusicTrack], Int) -> Void, refreshForYou: @escaping () -> Void, updateChatsQuery: @escaping (String) -> Void, searchChats: @escaping () -> Void, openMessage: @escaping (EngineMessage) -> Void, openLyrics: @escaping () -> Void, artwork: @escaping (MokoMusicTrack) -> UIImage?) {
        self.updateQuery = updateQuery
        self.search = search
        self.loadMore = loadMore
        self.openTrack = openTrack
        self.refreshForYou = refreshForYou
        self.updateChatsQuery = updateChatsQuery
        self.searchChats = searchChats
        self.openMessage = openMessage
        self.openLyrics = openLyrics
        self.artwork = artwork
    }
}

private enum MokoMusicRow: ItemListNodeEntry {
    case header(id: Int32, section: Int32, text: String)
    case nowPlaying(id: Int32, section: Int32, title: String, artist: String)
    case lyrics(id: Int32, section: Int32, title: String)
    case input(id: Int32, section: Int32, text: String, placeholder: String, chats: Bool)
    case track(id: Int32, section: Int32, track: MokoMusicTrack, list: [MokoMusicTrack], index: Int, liked: Bool)
    case message(id: Int32, section: Int32, message: EngineMessage, title: String, artist: String)
    case button(id: Int32, section: Int32, title: String, action: Int)
    case footer(id: Int32, section: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .nowPlaying(_, section, _, _), let .lyrics(_, section, _), let .input(_, section, _, _, _), let .track(_, section, _, _, _, _), let .message(_, section, _, _, _), let .button(_, section, _, _), let .footer(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .nowPlaying(id, _, _, _), let .lyrics(id, _, _), let .input(id, _, _, _, _), let .track(id, _, _, _, _, _), let .message(id, _, _, _, _), let .button(id, _, _, _), let .footer(id, _, _):
            return id
        }
    }

    static func ==(lhs: MokoMusicRow, rhs: MokoMusicRow) -> Bool {
        switch (lhs, rhs) {
        case let (.header(a, b, c), .header(d, e, f)):
            return a == d && b == e && c == f
        case let (.nowPlaying(a, b, c, x), .nowPlaying(d, e, f, y)):
            return a == d && b == e && c == f && x == y
        case let (.lyrics(a, b, c), .lyrics(d, e, f)):
            return a == d && b == e && c == f
        case let (.input(a, b, c, x, p), .input(d, e, f, y, q)):
            return a == d && b == e && c == f && x == y && p == q
        case let (.track(a, b, c, _, i, l), .track(d, e, f, _, j, m)):
            return a == d && b == e && c == f && i == j && l == m
        case let (.message(a, b, c, _, _), .message(d, e, f, _, _)):
            return a == d && b == e && c.id == f.id
        case let (.button(a, b, c, x), .button(d, e, f, y)):
            return a == d && b == e && c == f && x == y
        case let (.footer(a, b, c), .footer(d, e, f)):
            return a == d && b == e && c == f
        default:
            return false
        }
    }

    static func <(lhs: MokoMusicRow, rhs: MokoMusicRow) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MokoMusicArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .nowPlaying(_, _, title, artist):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: artist, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .lyrics(_, _, title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openLyrics()
            })
        case let .input(_, _, text, placeholder, chats):
            return ItemListSingleLineInputItem(presentationData: presentationData, systemStyle: .glass, title: NSAttributedString(), text: text, placeholder: placeholder, type: .regular(capitalization: false, autocorrection: false), returnKeyType: .search, clearType: .always, sectionId: self.section, textUpdated: { value in
                if chats {
                    arguments.updateChatsQuery(value)
                } else {
                    arguments.updateQuery(value)
                }
            }, action: {
                if chats {
                    arguments.searchChats()
                } else {
                    arguments.search()
                }
            })
        case let .track(_, _, track, list, index, liked):
            let duration = track.durationMs / 1000
            let label = String(format: "%d:%02d", duration / 60, duration % 60)
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: arguments.artwork(track), title: liked ? "\(track.title) ♥" : track.title, label: label, additionalDetailLabel: track.artist, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.openTrack(track, list, index)
            })
        case let .message(_, _, message, title, artist):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: "", additionalDetailLabel: artist, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.openMessage(message)
            })
        case let .button(_, _, title, action):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                switch action {
                case 0:
                    arguments.loadMore()
                case 1:
                    arguments.refreshForYou()
                default:
                    arguments.search()
                }
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func audioTitle(_ message: EngineMessage) -> (String, String) {
    for media in message.media {
        if let file = media as? TelegramMediaFile {
            for attribute in file.attributes {
                if case let .Audio(false, _, title, performer, _) = attribute {
                    return (title ?? file.fileName ?? "", performer ?? "")
                }
            }
            return (file.fileName ?? "", "")
        }
    }
    return ("", "")
}

private func mokoMusicRows(state: MokoMusicState, current: MokoMusicTrack?, strings: PresentationStrings) -> [MokoMusicRow] {
    var rows: [MokoMusicRow] = []
    // Ids are fixed per role (tracks and messages by position in their own range), so switching a
    // tab never hands an item node a row of another kind.
    if let current {
        rows.append(.header(id: 0, section: 0, text: strings.moko("Сейчас играет")))
        rows.append(.nowPlaying(id: 1, section: 0, title: current.title, artist: current.artist))
    }
    let tracks: (String, [MokoMusicTrack]) -> Void = { title, list in
        if !title.isEmpty {
            rows.append(.header(id: 20, section: 2, text: title))
        }
        for (index, track) in list.enumerated() {
            rows.append(.track(id: 1000 + Int32(index), section: 2, track: track, list: list, index: index, liked: MokoMusicContext.shared.library.isLiked(track.id)))
        }
    }
    switch state.tab {
    case .search:
        rows.append(.input(id: 10, section: 1, text: state.query, placeholder: strings.moko("Поиск в SoundCloud"), chats: false))
        if let error = state.error {
            rows.append(.footer(id: 11, section: 1, text: error))
            rows.append(.button(id: 12, section: 1, title: strings.moko("Повторить"), action: 2))
        } else if state.searching && state.results.isEmpty {
            rows.append(.footer(id: 11, section: 1, text: strings.moko("Ищу…")))
        }
        tracks("", state.results)
        if state.nextOffset != nil {
            rows.append(.button(id: 900, section: 3, title: state.searching ? strings.moko("Загрузка…") : strings.moko("Ещё"), action: 0))
        }
    case .forYou:
        rows.append(.button(id: 10, section: 1, title: state.forYouLoading ? strings.moko("Подбираю…") : strings.moko("Обновить"), action: 1))
        if !state.forYouNote.isEmpty {
            rows.append(.footer(id: 11, section: 1, text: strings.moko(state.forYouNote)))
        }
        tracks(strings.moko("Для вас"), state.forYou)
    case .likes:
        let liked = MokoMusicContext.shared.library.likedTracks()
        if liked.isEmpty {
            rows.append(.footer(id: 11, section: 1, text: strings.moko("Здесь появятся треки, которым вы поставили сердечко.")))
        }
        tracks("", liked)
    case .chats:
        rows.append(.input(id: 10, section: 1, text: state.chatsQuery, placeholder: strings.moko("Поиск музыки по чатам"), chats: true))
        if state.chatsSearching {
            rows.append(.footer(id: 11, section: 1, text: strings.moko("Ищу…")))
        }
        for (index, message) in state.chatsResults.enumerated() {
            let (title, artist) = audioTitle(message)
            rows.append(.message(id: 5000 + Int32(index), section: 2, message: message, title: title, artist: artist))
        }
    }
    return rows
}

/// The mokaGram "Music" screen: SoundCloud search, "For you", likes and music found in chats.
public func mokoMusicController(context: AccountContext, initialQuery: String?) -> ViewController {
    let music = MokoMusicContext.shared
    let lastQueryKey = "mokoGram.music.lastQuery"
    var initial = MokoMusicState()
    initial.query = initialQuery ?? (MokoStorage.defaults.string(forKey: lastQueryKey) ?? "")
    let statePromise = ValuePromise(initial, ignoreRepeated: true)
    let stateValue = Atomic(value: initial)
    let updateState: ((inout MokoMusicState) -> Void) -> Void = { f in
        statePromise.set(stateValue.modify { state in
            var state = state
            f(&state)
            return state
        })
    }
    let searchDisposable = MetaDisposable()
    let forYouDisposable = MetaDisposable()
    let chatsDisposable = MetaDisposable()
    let artworkVersion = ValuePromise<Int>(0, ignoreRepeated: true)
    let artworkCache = Atomic<[String: UIImage]>(value: [:])
    let artworkLoading = Atomic<Set<String>>(value: [])
    var controllerRef: (() -> ViewController?)?

    let runSearch: (Bool) -> Void = { more in
        let state = stateValue.with { $0 }
        let query = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        MokoStorage.defaults.set(query, forKey: lastQueryKey)
        let offset = more ? (state.nextOffset ?? 0) : 0
        updateState { state in
            state.searching = true
            state.error = nil
            if !more {
                state.results = []
                state.nextOffset = nil
            }
        }
        searchDisposable.set((music.client.search(query, offset: offset)
        |> deliverOnMainQueue).start(next: { page in
            updateState { state in
                state.searching = false
                state.results = more ? state.results + page.tracks : page.tracks
                state.nextOffset = page.nextOffset
            }
        }, error: { error in
            let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
            updateState { state in
                state.searching = false
                state.error = MokoTrackActions.errorText(error, strings: strings)
            }
        }))
    }

    let refreshForYou: () -> Void = {
        updateState { $0.forYouLoading = true }
        forYouDisposable.set((MokoRecommender.buildForYou(library: music.library, source: music.client, count: 30, random: { Double.random(in: 0 ..< 1) })
        |> deliverOnMainQueue).start(next: { result in
            updateState { state in
                state.forYouLoading = false
                state.forYou = result.tracks
                state.forYouNote = result.note
            }
        }))
    }

    let arguments = MokoMusicArguments(updateQuery: { value in
        updateState { $0.query = value }
    }, search: {
        runSearch(false)
    }, loadMore: {
        if !stateValue.with({ $0.searching }) {
            runSearch(true)
        }
    }, openTrack: { track, list, index in
        guard let controller = controllerRef?() else {
            return
        }
        MokoTrackActions.present(track: track, context: context, from: controller, play: {
            music.play(list, startIndex: index, context: context)
        })
    }, refreshForYou: {
        refreshForYou()
    }, updateChatsQuery: { value in
        updateState { $0.chatsQuery = value }
    }, searchChats: {
        let query = stateValue.with { $0.chatsQuery }.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        updateState { $0.chatsSearching = true }
        chatsDisposable.set((context.engine.messages.searchMessages(location: .general(scope: .everywhere, groupId: nil, tags: .music, minDate: nil, maxDate: nil, folderId: nil, communityId: nil), query: query, state: nil)
        |> deliverOnMainQueue).start(next: { result, _ in
            updateState { state in
                state.chatsSearching = false
                state.chatsResults = result.messages.map(EngineMessage.init)
            }
        }))
    }, openMessage: { message in
        let messages = stateValue.with { $0.chatsResults }.map { $0._asMessage() }
        let playlistLocation = PeerMessagesPlaylistLocation.custom(messages: .single((messages, Int32(messages.count), false)), canReorder: false, at: message.id, loadMore: nil, hidePanel: false)
        let _ = context.sharedContext.openChatMessage(OpenChatMessageParams(context: context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message._asMessage(), standalone: false, reverseMessageGalleryOrder: false, navigationController: nil, dismissInput: {}, present: { _, _, _ in }, transitionNode: { _, _, _ in return nil }, addToTransitionSurface: { _ in }, openUrl: { _ in }, openPeer: { _, _ in }, callPeer: { _, _ in }, openConferenceCall: { _ in }, enqueueMessage: { _ in }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: playlistLocation))
    }, openLyrics: {
    }, artwork: { track in
        if let image = artworkCache.with({ $0[track.id] }) {
            return image
        }
        var shouldLoad = false
        let _ = artworkLoading.modify { loading in
            if loading.contains(track.id) {
                return loading
            }
            shouldLoad = true
            return loading.union([track.id])
        }
        guard shouldLoad, let url = URL(string: track.artworkUrl), !track.artworkUrl.isEmpty else {
            return nil
        }
        URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
            guard let data, let source = UIImage(data: data) else {
                return
            }
            let size = CGSize(width: 40.0, height: 40.0)
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6.0).addClip()
                source.draw(in: CGRect(origin: .zero, size: size))
            }
            let _ = artworkCache.modify { cache in
                var cache = cache
                cache[track.id] = image
                return cache
            }
            Queue.mainQueue().async {
                artworkVersion.set(artworkCache.with { $0.count })
            }
        }).resume()
        return nil
    })

    let likesChanged: Signal<Void, NoError> = .single(Void()) |> then(music.library.changed)
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get(), music.currentQueue, artworkVersion.get(), likesChanged)
    |> map { presentationData, state, queue, _, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings
        let tabs = [strings.moko("Поиск"), strings.moko("Для вас"), strings.moko("Лайки"), strings.moko("В чатах")]
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .sectionControl(tabs, state.tab.rawValue), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: mokoMusicRows(state: state, current: queue?.current, strings: strings), style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        searchDisposable.dispose()
        forYouDisposable.dispose()
        chatsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    controller.titleControlValueChanged = { index in
        let tab = MokoMusicTab(rawValue: index) ?? .search
        updateState { $0.tab = tab }
        if tab == .forYou && stateValue.with({ $0.forYou.isEmpty && !$0.forYouLoading }) {
            refreshForYou()
        }
    }
    controllerRef = { [weak controller] in
        return controller
    }
    if !initial.query.isEmpty {
        runSearch(false)
    }
    return controller
}
