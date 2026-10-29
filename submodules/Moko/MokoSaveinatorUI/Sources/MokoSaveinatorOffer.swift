import Foundation
import UIKit
import Display
import AccountContext
import TelegramPresentationData
import MokoCore
import MokoSaveinator
import MokoSettingsUI
import TelegramCore


/// The choice shown when the user sends nothing but a link to a supported service (Desktop `ChooseBox`).
public enum MokoSaveinatorOffer {
    private static let mediaKey = "saveinator.media"
    private static let qualityKey = "saveinator.quality"
    private static let mediaTitles = ["Всё", "Видео", "Звук", "Фото"]
    private static let qualityTitles = ["Макс", "1080", "720", "480", "360"]

    /// Whether `text` should be taken over: the setting is on, a key is configured and the whole
    /// text is one supported link. Returns that link.
    public static func link(in text: String) -> String? {
        guard MokoSettings.bool("saveinator.enabled", accountId: 0), MokoSaveinatorConfiguration.current() != nil else {
            return nil
        }
        return MokoSaveinatorLink.loneLink(in: text)
    }

    /// Whether the offer may be made at all: the setting is on and a key is configured.
    public static var isAvailable: Bool {
        return MokoSettings.bool("saveinator.enabled", accountId: 0) && MokoSaveinatorConfiguration.current() != nil
    }

    /// The first supported link in a message: `url`/`textUrl` entities in order, then a plain scan
    /// of the text. Nil when the offer is unavailable or the message holds no supported link.
    public static func link(inMessage message: EngineRawMessage) -> String? {
        guard isAvailable else {
            return nil
        }
        let text = message.text
        let nsText = text as NSString
        var candidates: [String] = []
        for attribute in message.attributes {
            guard let attribute = attribute as? TextEntitiesMessageAttribute else {
                continue
            }
            for entity in attribute.entities.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
                switch entity.type {
                case .Url:
                    let range = NSRange(location: entity.range.lowerBound, length: entity.range.count)
                    if range.location >= 0, NSMaxRange(range) <= nsText.length {
                        candidates.append(nsText.substring(with: range))
                    }
                case let .TextUrl(url):
                    candidates.append(url)
                default:
                    break
                }
            }
        }
        if candidates.isEmpty, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            for match in detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) {
                if let url = match.url?.absoluteString {
                    candidates.append(url)
                }
            }
        }
        for candidate in candidates {
            if let link = MokoSaveinatorLink.normalized(candidate.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return link
            }
        }
        return nil
    }

    /// "Download by link" for a link that already sits in a message (context menus): asks for the
    /// media and quality, then sends the files to `peerId`/`threadId`. The input field is untouched.
    public static func presentForLinkInMessage(context: AccountContext, link: String, peerId: EnginePeer.Id, threadId: Int64?) {
        present(context: context, link: link, sendAsText: nil, download: { choice in
            let destination = MokoSaveinatorDestination(peerId: peerId, threadId: threadId, replySubject: nil, silent: nil, scheduleTime: nil, repeatPeriod: nil)
            MokoSaveinatorTransfer.start(context: context, link: link, choice: choice, destination: destination, send: { messages in
                let _ = enqueueMessages(account: context.account, peerId: peerId, messages: messages).startStandalone()
                return true
            }, failed: {})
        })
    }

    /// `sendAsText` sends the original message; `download` starts the download with the chosen
    /// options. Dismissing the sheet does neither and leaves the text in the input field.
    public static func present(context: AccountContext, link: String, sendAsText: (() -> Void)?, download: @escaping (MokoSaveinatorChoice) -> Void) {
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        let host = MokoSaveinatorLink.host(of: link)
        let path = URLComponents(string: link)?.path ?? ""
        let shown = host + (path == "/" ? "" : path)
        let message: String
        if let platform = MokoSaveinatorLink.platform(host: host) {
            let title = platform == .yandexMusic ? strings.moko(MokoSaveinatorLink.platformTitle(platform)) : MokoSaveinatorLink.platformTitle(platform)
            message = title + " · " + shown
        } else {
            message = shown
        }

        let sheet = UIAlertController(title: strings.moko("Скачать по ссылке"), message: message, preferredStyle: .actionSheet)
        let savedMedia = MokoSettings.int(mediaKey, accountId: 0)
        for index in MokoSaveinatorLink.availableMedia(for: link) {
            let title = strings.moko(mediaTitles[index]) + (index == savedMedia ? " ✓" : "")
            sheet.addAction(UIAlertAction(title: title, style: .default, handler: { _ in
                MokoSettings.set(.int(index), for: mediaKey, accountId: 0)
                if MokoSaveinatorChoice.mediaHasVideo(index) {
                    presentQuality(context: context, media: index, download: download)
                } else {
                    download(MokoSaveinatorChoice.make(media: index, quality: 0))
                }
            }))
        }
        if let sendAsText {
            sheet.addAction(UIAlertAction(title: strings.moko("Ссылкой"), style: .default, handler: { _ in
                sendAsText()
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.moko("Отмена"), style: .cancel, handler: nil))
        present(context, sheet)
    }

    private static func presentQuality(context: AccountContext, media: Int, download: @escaping (MokoSaveinatorChoice) -> Void) {
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        let sheet = UIAlertController(title: strings.moko("Качество"), message: nil, preferredStyle: .actionSheet)
        let saved = MokoSettings.int(qualityKey, accountId: 0)
        for (index, title) in qualityTitles.enumerated() {
            let shown = (index == 0 ? strings.moko(title) : title) + (index == saved ? " ✓" : "")
            sheet.addAction(UIAlertAction(title: shown, style: .default, handler: { _ in
                MokoSettings.set(.int(index), for: qualityKey, accountId: 0)
                download(MokoSaveinatorChoice.make(media: media, quality: index))
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.moko("Отмена"), style: .cancel, handler: nil))
        present(context, sheet)
    }

    private static func present(_ context: AccountContext, _ controller: UIViewController) {
        if let window = context.sharedContext.applicationBindings.getTopWindow(), let popover = controller.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        context.sharedContext.applicationBindings.presentNativeController(controller)
    }
}
