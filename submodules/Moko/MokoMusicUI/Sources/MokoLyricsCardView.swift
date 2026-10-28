import Foundation
import UIKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import MokoCore
import MokoMusic
import MokoSettingsUI

private final class MokoLyricLineCell: UITableViewCell {
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .none
        self.label.numberOfLines = 0
        self.label.font = UIFont.systemFont(ofSize: 22.0, weight: .bold)
        self.contentView.addSubview(self.label)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.label.frame = self.contentView.bounds.insetBy(dx: 16.0, dy: 7.0)
    }
}

/// The Lyrics card of the expanded player: synced lyrics with the current line highlighted, scrolling
/// with playback, a tapped line seeks to its time, and a button that opens the lyrics full screen.
public final class MokoLyricsCardView: UIView, UITableViewDataSource, UITableViewDelegate {
    private let model: MokoLyricsModel
    private let titleLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let statusLabel = UILabel()
    private var disposable: Disposable?

    private var state = MokoLyricsState()
    private var strings: PresentationStrings
    /// Manual scrolling pauses following the current line until this time.
    private var followPausedUntil: Double = 0.0
    private var lastScrolledLine: Int?

    public var requestExpand: (() -> Void)?

    public init(context: AccountContext, strings: PresentationStrings) {
        self.model = MokoLyricsModel(context: context)
        self.strings = strings

        super.init(frame: .zero)

        self.layer.cornerRadius = 20.0
        self.layer.cornerCurve = .continuous
        self.clipsToBounds = true
        self.backgroundColor = UIColor(white: 1.0, alpha: 0.16)

        self.titleLabel.font = UIFont.systemFont(ofSize: 15.0, weight: .semibold)
        self.titleLabel.textColor = .white
        self.titleLabel.text = strings.moko("Текст песни")
        self.addSubview(self.titleLabel)

        self.expandButton.setImage(UIImage(systemName: "arrow.up.left.and.arrow.down.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13.0, weight: .semibold)), for: .normal)
        self.expandButton.tintColor = .white
        self.expandButton.backgroundColor = UIColor(white: 0.0, alpha: 0.25)
        self.expandButton.layer.cornerRadius = 16.0
        self.expandButton.addTarget(self, action: #selector(self.expandPressed), for: .touchUpInside)
        self.expandButton.accessibilityLabel = strings.moko("Текст песни")
        self.addSubview(self.expandButton)

        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(MokoLyricLineCell.self, forCellReuseIdentifier: "line")
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44.0
        self.addSubview(self.tableView)

        self.statusLabel.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
        self.statusLabel.textColor = UIColor(white: 1.0, alpha: 0.75)
        self.statusLabel.textAlignment = .center
        self.statusLabel.numberOfLines = 0
        self.addSubview(self.statusLabel)

        self.disposable = (self.model.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            self?.apply(state)
        })
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    deinit {
        self.disposable?.dispose()
    }

    public func updateStrings(_ strings: PresentationStrings) {
        self.strings = strings
        self.titleLabel.text = strings.moko("Текст песни")
        self.updateStatus()
    }

    @objc private func expandPressed() {
        self.requestExpand?()
    }

    /// Whether a point (in this view's coordinate space) belongs to the card, whose own scrolling must
    /// win over the sheet's drag gestures.
    public func ownsTouch(at point: CGPoint) -> Bool {
        return self.bounds.contains(point)
    }

    /// `size` is the card's size; the frame is set by the caller.
    public func updateLayout(size: CGSize) {
        let headerHeight: CGFloat = 48.0
        self.titleLabel.frame = CGRect(x: 16.0, y: 12.0, width: size.width - 80.0, height: 24.0)
        self.expandButton.frame = CGRect(x: size.width - 16.0 - 32.0, y: 8.0, width: 32.0, height: 32.0)
        self.tableView.frame = CGRect(x: 0.0, y: headerHeight, width: size.width, height: max(0.0, size.height - headerHeight))
        self.statusLabel.frame = CGRect(x: 20.0, y: headerHeight, width: size.width - 40.0, height: max(0.0, size.height - headerHeight - 8.0))
        self.tableView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(0.0, size.height - headerHeight - 80.0), right: 0.0)
    }

    private var lines: [MokoLyricLine] {
        if let lyrics = self.state.lyrics, lyrics.found {
            return lyrics.lines
        }
        return []
    }

    private func updateStatus() {
        let text: String?
        if self.state.track == nil {
            text = self.strings.moko("Сейчас ничего не играет.")
        } else if self.state.loading {
            text = self.strings.moko("Ищу текст…")
        } else if self.lines.isEmpty {
            text = self.strings.moko("Текст не найден")
        } else {
            text = nil
        }
        self.statusLabel.text = text
        self.statusLabel.isHidden = text == nil
        self.tableView.isHidden = text != nil
    }

    private func apply(_ state: MokoLyricsState) {
        let previous = self.state
        self.state = state
        self.updateStatus()
        if previous.lyrics != state.lyrics || previous.track != state.track {
            self.lastScrolledLine = nil
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: false)
            return
        }
        guard previous.currentLine != state.currentLine else {
            return
        }
        var rows: [IndexPath] = []
        for line in [previous.currentLine, state.currentLine] {
            if let line, line < self.lines.count {
                rows.append(IndexPath(row: line, section: 0))
            }
        }
        for indexPath in rows {
            if let cell = self.tableView.cellForRow(at: indexPath) as? MokoLyricLineCell {
                self.configure(cell, row: indexPath.row)
            }
        }
        if let line = state.currentLine, line < self.lines.count, CACurrentMediaTime() >= self.followPausedUntil, !self.tableView.isTracking, !self.tableView.isDecelerating {
            self.lastScrolledLine = line
            self.tableView.scrollToRow(at: IndexPath(row: line, section: 0), at: .top, animated: true)
        }
    }

    private func configure(_ cell: MokoLyricLineCell, row: Int) {
        let lines = self.lines
        guard row < lines.count else {
            return
        }
        let synced = self.state.lyrics?.synced ?? false
        let text = lines[row].text
        cell.label.text = text.isEmpty ? "♪" : text
        // Unsynced text has no current line: show it all at full strength.
        let isCurrent = !synced || row == self.state.currentLine
        cell.label.textColor = isCurrent ? .white : UIColor(white: 1.0, alpha: 0.5)
    }

    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.lines.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "line", for: indexPath) as! MokoLyricLineCell
        self.configure(cell, row: indexPath.row)
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        // Lines without timestamps have no time to seek to.
        guard self.state.lyrics?.synced == true, indexPath.row < self.lines.count else {
            return
        }
        self.model.seek(toMs: self.lines[indexPath.row].timeMs)
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.followPausedUntil = CACurrentMediaTime() + 3.0
    }
}
