import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import MusicAlbumArtResources
import MokoCore
import MokoMusic
import MokoSettingsUI

private let mokoCoverCache = NSCache<NSString, UIImage>()
private let mokoPlaceholderCache = NSCache<NSString, UIImage>()

private func mokoPlaceholderCover(_ track: MokoMusicTrack) -> UIImage {
    let seed = MusicCoverPlaceholder.seed(title: track.title, performer: track.artist)
    if let image = mokoPlaceholderCache.object(forKey: seed as NSString) {
        return image
    }
    let image = MusicCoverPlaceholder.image(size: CGSize(width: 96.0, height: 96.0), seed: seed)
    mokoPlaceholderCache.setObject(image, forKey: seed as NSString)
    return image
}

private final class MokoMusicTrackCell: UITableViewCell {
    let coverView = UIImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    let durationLabel = UILabel()
    let likeButton = UIButton(type: .system)
    var onLike: (() -> Void)?
    private(set) var trackId: String?
    private var coverTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .default
        self.coverView.layer.cornerRadius = 8.0
        self.coverView.layer.cornerCurve = .continuous
        self.coverView.clipsToBounds = true
        self.coverView.contentMode = .scaleAspectFill
        self.titleLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
        self.artistLabel.font = UIFont.systemFont(ofSize: 14.0)
        self.durationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 13.0, weight: .regular)
        self.durationLabel.textAlignment = .right
        self.likeButton.addTarget(self, action: #selector(self.likePressed), for: .touchUpInside)
        self.contentView.addSubview(self.coverView)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.artistLabel)
        self.contentView.addSubview(self.durationLabel)
        self.contentView.addSubview(self.likeButton)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    @objc private func likePressed() {
        self.onLike?()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.coverTask?.cancel()
        self.coverTask = nil
    }

    func configure(track: MokoMusicTrack, liked: Bool, playing: Bool, theme: PresentationTheme) {
        self.trackId = track.id
        self.titleLabel.text = track.title
        self.artistLabel.text = track.artist
        let seconds = track.durationMs / 1000
        self.durationLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        self.titleLabel.textColor = playing ? theme.list.itemAccentColor : theme.list.itemPrimaryTextColor
        self.artistLabel.textColor = theme.list.itemSecondaryTextColor
        self.durationLabel.textColor = theme.list.itemSecondaryTextColor
        self.likeButton.setImage(UIImage(systemName: liked ? "heart.fill" : "heart", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17.0, weight: .regular)), for: .normal)
        self.likeButton.tintColor = liked ? theme.list.itemAccentColor : theme.list.itemSecondaryTextColor
        self.likeButton.accessibilityLabel = liked ? "Unlike" : "Like"
        self.selectedBackgroundView = {
            let view = UIView()
            view.backgroundColor = theme.list.itemHighlightedBackgroundColor
            return view
        }()
        self.loadCover(track)
    }

    private func loadCover(_ track: MokoMusicTrack) {
        // One resolver for SoundCloud art: the catalogue artwork, else the generated placeholder the
        // players draw for a track without any.
        guard !track.artworkUrl.isEmpty, let url = URL(string: track.artworkUrl) else {
            self.coverView.image = mokoPlaceholderCover(track)
            return
        }
        if let image = mokoCoverCache.object(forKey: track.artworkUrl as NSString) {
            self.coverView.image = image
            return
        }
        self.coverView.image = mokoPlaceholderCover(track)
        let trackId = track.id
        self.coverTask = URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else {
                return
            }
            mokoCoverCache.setObject(image, forKey: track.artworkUrl as NSString)
            DispatchQueue.main.async {
                if let self, self.trackId == trackId {
                    self.coverView.image = image
                }
            }
        })
        self.coverTask?.resume()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.contentView.bounds
        let side: CGFloat = 48.0
        self.coverView.frame = CGRect(x: 12.0, y: floor((bounds.height - side) / 2.0), width: side, height: side)
        let likeWidth: CGFloat = 44.0
        self.likeButton.frame = CGRect(x: bounds.width - likeWidth - 4.0, y: floor((bounds.height - 44.0) / 2.0), width: likeWidth, height: 44.0)
        let durationWidth: CGFloat = 44.0
        self.durationLabel.frame = CGRect(x: self.likeButton.frame.minX - durationWidth, y: 14.0, width: durationWidth, height: 18.0)
        let textLeft = self.coverView.frame.maxX + 12.0
        let textWidth = self.durationLabel.frame.minX - textLeft - 4.0
        self.titleLabel.frame = CGRect(x: textLeft, y: 12.0, width: max(0.0, textWidth), height: 20.0)
        self.artistLabel.frame = CGRect(x: textLeft, y: 33.0, width: max(0.0, bounds.width - textLeft - likeWidth - 8.0), height: 18.0)
    }
}

/// The "Search" tab of the player sheet: SoundCloud search, "For You" and "Likes" (what the
/// standalone mokaGram music screen used to be). Tapping a track plays it in a queue made of the list
/// it was tapped in; the heart toggles a like; a long press opens the track's actions.
public final class MokoMusicSearchPanelView: UIView, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    public enum Section: Int {
        case search
        case forYou
        case likes
    }

    private static let lastQueryKey = "mokoGram.music.lastQuery"

    private let context: AccountContext
    private var theme: PresentationTheme
    private var strings: PresentationStrings

    /// The sub-section switch. The sheet places it in its header, so it stays in view when the list scrolls.
    public let sectionControl = UISegmentedControl(items: [])
    private let searchField = UISearchTextField()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statusLabel = UILabel()
    private let retryButton = UIButton(type: .system)

    public var presentActions: ((MokoMusicTrack) -> Void)?

    private var section: Section = .search
    private var query: String = ""
    private var results: [MokoMusicTrack] = []
    private var nextOffset: Int?
    private var searching = false
    private var searchError: String?
    private var forYou: [MokoMusicTrack] = []
    private var forYouNote = ""
    private var forYouLoading = false
    private var forYouLoaded = false
    private var forYouError = false
    private var likes: [MokoMusicTrack] = []
    private var playingTrackId: String?
    private var didActivate = false
    private var bottomInset: CGFloat = 0.0

    private let searchDisposable = MetaDisposable()
    private let forYouDisposable = MetaDisposable()
    private var libraryDisposable: Disposable?
    private var queueDisposable: Disposable?
    private var debounceItem: DispatchWorkItem?

    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        self.strings = strings

        super.init(frame: .zero)

        self.query = MokoStorage.defaults.string(forKey: MokoMusicSearchPanelView.lastQueryKey) ?? ""

        self.searchField.text = self.query
        self.searchField.returnKeyType = .search
        self.searchField.autocorrectionType = .no
        self.searchField.autocapitalizationType = .none
        self.searchField.clearButtonMode = .whileEditing
        self.searchField.delegate = self
        self.searchField.addTarget(self, action: #selector(self.queryChanged), for: .editingChanged)
        self.addSubview(self.searchField)

        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.rowHeight = 64.0
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.register(MokoMusicTrackCell.self, forCellReuseIdentifier: "track")
        self.tableView.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:))))
        self.addSubview(self.tableView)

        self.statusLabel.font = UIFont.systemFont(ofSize: 15.0)
        self.statusLabel.textAlignment = .center
        self.statusLabel.numberOfLines = 0
        self.addSubview(self.statusLabel)

        self.retryButton.addTarget(self, action: #selector(self.retryPressed), for: .touchUpInside)
        self.addSubview(self.retryButton)

        self.sectionControl.addTarget(self, action: #selector(self.sectionChanged), for: .valueChanged)

        self.updateStrings(strings)
        self.updateTheme(theme)

        let music = MokoMusicContext.shared
        self.likes = music.library.likedTracks()
        self.libraryDisposable = (music.library.changed
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let self else {
                return
            }
            self.likes = MokoMusicContext.shared.library.likedTracks()
            self.reload()
        })
        self.queueDisposable = (music.currentQueue
        |> deliverOnMainQueue).start(next: { [weak self] queue in
            guard let self else {
                return
            }
            let id = queue?.current?.id
            if id != self.playingTrackId {
                self.playingTrackId = id
                self.reload()
            }
        })
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    deinit {
        self.searchDisposable.dispose()
        self.forYouDisposable.dispose()
        self.libraryDisposable?.dispose()
        self.queueDisposable?.dispose()
    }

    public func updateStrings(_ strings: PresentationStrings) {
        self.strings = strings
        let titles = [strings.moko("Поиск"), strings.moko("Для вас"), strings.moko("Лайки")]
        let selected = self.sectionControl.numberOfSegments == 3 ? self.sectionControl.selectedSegmentIndex : self.section.rawValue
        self.sectionControl.removeAllSegments()
        for (index, title) in titles.enumerated() {
            self.sectionControl.insertSegment(withTitle: title, at: index, animated: false)
        }
        self.sectionControl.selectedSegmentIndex = selected
        self.searchField.placeholder = strings.moko("Поиск в SoundCloud")
        self.retryButton.setTitle(strings.moko("Повторить"), for: .normal)
        self.updateStatus()
    }

    public func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        self.statusLabel.textColor = theme.list.itemSecondaryTextColor
        self.retryButton.tintColor = theme.list.itemAccentColor
        self.overrideUserInterfaceStyle = theme.overallDarkAppearance ? .dark : .light
        self.reload()
    }

    /// Called when the tab becomes visible: restores the last query and loads the first page once.
    public func activate() {
        guard !self.didActivate else {
            return
        }
        self.didActivate = true
        if !self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.runSearch(more: false)
        }
        self.updateStatus()
    }

    public func updateLayout(size: CGSize, bottomInset: CGFloat) {
        self.bottomInset = bottomInset
        let sideInset: CGFloat = 16.0
        let showsField = self.section == .search
        let fieldHeight: CGFloat = showsField ? 40.0 : 0.0
        self.searchField.isHidden = !showsField
        self.searchField.frame = CGRect(x: sideInset, y: 6.0, width: size.width - sideInset * 2.0, height: 40.0)
        let tableTop = showsField ? fieldHeight + 12.0 : 4.0
        self.tableView.frame = CGRect(x: sideInset, y: tableTop, width: size.width - sideInset * 2.0, height: max(0.0, size.height - tableTop))
        self.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0)
        self.tableView.verticalScrollIndicatorInsets = self.tableView.contentInset
        let statusTop = tableTop + 24.0
        self.statusLabel.frame = CGRect(x: 32.0, y: statusTop, width: size.width - 64.0, height: 60.0)
        self.retryButton.frame = CGRect(x: floor((size.width - 140.0) / 2.0), y: statusTop + 62.0, width: 140.0, height: 36.0)
    }

    // MARK: - State

    private var currentTracks: [MokoMusicTrack] {
        switch self.section {
        case .search:
            return self.results
        case .forYou:
            return self.forYou
        case .likes:
            return self.likes
        }
    }

    private func reload() {
        self.tableView.reloadData()
        self.updateStatus()
    }

    private func updateStatus() {
        var text: String?
        var canRetry = false
        let isEmpty = self.currentTracks.isEmpty
        switch self.section {
        case .search:
            if let error = self.searchError {
                text = error
                canRetry = true
            } else if self.searching && isEmpty {
                text = self.strings.moko("Ищу…")
            } else if isEmpty {
                text = self.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? self.strings.moko("Введите название трека или исполнителя") : self.strings.moko("Ничего не найдено")
            }
        case .forYou:
            if self.forYouError && isEmpty {
                text = self.strings.moko("сеть: нет соединения")
                canRetry = true
            } else if self.forYouLoading && isEmpty {
                text = self.strings.moko("Подбираю…")
            } else if isEmpty && self.forYouLoaded {
                text = self.strings.moko("Пока нечего посоветовать. Послушайте или полайкайте несколько треков.")
            } else if !self.forYouNote.isEmpty && isEmpty {
                text = self.strings.moko(self.forYouNote)
            }
        case .likes:
            if isEmpty {
                text = self.strings.moko("Здесь появятся треки, которым вы поставили сердечко.")
            }
        }
        self.statusLabel.text = text
        self.statusLabel.isHidden = text == nil
        self.retryButton.isHidden = !canRetry
    }

    @objc private func sectionChanged() {
        self.section = Section(rawValue: self.sectionControl.selectedSegmentIndex) ?? .search
        if self.section == .forYou && !self.forYouLoaded && !self.forYouLoading {
            self.refreshForYou()
        }
        self.searchField.resignFirstResponder()
        self.setNeedsLayoutFromSection()
        self.reload()
        self.tableView.setContentOffset(CGPoint(x: 0.0, y: -self.tableView.contentInset.top), animated: false)
    }

    private func setNeedsLayoutFromSection() {
        self.updateLayout(size: self.bounds.size, bottomInset: self.bottomInset)
    }

    @objc private func retryPressed() {
        switch self.section {
        case .search:
            self.runSearch(more: false)
        case .forYou:
            self.refreshForYou()
        case .likes:
            break
        }
    }

    // MARK: - Search

    @objc private func queryChanged() {
        self.query = self.searchField.text ?? ""
        self.debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.runSearch(more: false)
        }
        self.debounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.debounceItem?.cancel()
        textField.resignFirstResponder()
        self.runSearch(more: false)
        return true
    }

    private func runSearch(more: Bool) {
        let query = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            self.searchDisposable.set(nil)
            self.results = []
            self.nextOffset = nil
            self.searching = false
            self.searchError = nil
            self.reload()
            return
        }
        MokoStorage.defaults.set(query, forKey: MokoMusicSearchPanelView.lastQueryKey)
        let offset = more ? (self.nextOffset ?? 0) : 0
        self.searching = true
        self.searchError = nil
        if !more {
            self.results = []
            self.nextOffset = nil
        }
        self.reload()
        self.searchDisposable.set((MokoMusicContext.shared.client.search(query, offset: offset)
        |> deliverOnMainQueue).start(next: { [weak self] page in
            guard let self else {
                return
            }
            self.searching = false
            self.results = more ? self.results + page.tracks : page.tracks
            self.nextOffset = page.nextOffset
            self.reload()
        }, error: { [weak self] error in
            guard let self else {
                return
            }
            self.searching = false
            self.searchError = MokoTrackActions.errorText(error, strings: self.strings)
            self.reload()
        }))
    }

    private func refreshForYou() {
        self.forYouLoading = true
        self.forYouError = false
        self.updateStatus()
        let music = MokoMusicContext.shared
        self.forYouDisposable.set((MokoRecommender.buildForYou(library: music.library, source: music.client, count: 30, random: { Double.random(in: 0 ..< 1) })
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            self.forYouLoading = false
            self.forYouLoaded = true
            self.forYouError = result.tracks.isEmpty && result.note.isEmpty
            self.forYou = result.tracks
            self.forYouNote = result.note
            self.reload()
        }))
    }

    // MARK: - Table

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.currentTracks.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "track", for: indexPath) as! MokoMusicTrackCell
        let tracks = self.currentTracks
        guard indexPath.row < tracks.count else {
            return cell
        }
        let track = tracks[indexPath.row]
        cell.configure(track: track, liked: MokoMusicContext.shared.library.isLiked(track.id), playing: track.id == self.playingTrackId, theme: self.theme)
        cell.onLike = {
            let library = MokoMusicContext.shared.library
            library.setLiked(track, !library.isLiked(track.id))
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if self.section == .search, self.nextOffset != nil, !self.searching, indexPath.row >= self.results.count - 3 {
            self.runSearch(more: true)
        }
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let tracks = self.currentTracks
        guard indexPath.row < tracks.count else {
            return
        }
        MokoMusicContext.shared.play(tracks, startIndex: indexPath.row, context: self.context)
    }

    @objc private func longPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let indexPath = self.tableView.indexPathForRow(at: recognizer.location(in: self.tableView)) else {
            return
        }
        let tracks = self.currentTracks
        if indexPath.row < tracks.count {
            self.presentActions?(tracks[indexPath.row])
        }
    }
}
