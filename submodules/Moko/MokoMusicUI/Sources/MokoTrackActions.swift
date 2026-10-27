import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import UndoUI
import MokoMusic
import MokoSettingsUI

/// The actions of a track row (Desktop's track context menu), as a native action sheet.
public enum MokoTrackActions {
    static func toast(_ context: AccountContext, _ text: String) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), on: .root, blockInteraction: false, completion: {})
    }

    static func presentNative(_ context: AccountContext, _ controller: UIViewController) {
        if let window = context.sharedContext.applicationBindings.getTopWindow(), let popover = controller.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
        }
        context.sharedContext.applicationBindings.presentNativeController(controller)
    }

    /// `play` starts the list the row belongs to from this track.
    public static func present(track: MokoMusicTrack, context: AccountContext, from controller: ViewController, play: @escaping () -> Void) {
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        let music = MokoMusicContext.shared
        let sheet = UIAlertController(title: track.title, message: track.artist, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: strings.moko("Слушать"), style: .default, handler: { _ in
            play()
        }))
        let liked = music.library.isLiked(track.id)
        sheet.addAction(UIAlertAction(title: strings.moko(liked ? "Убрать из понравившихся" : "Нравится"), style: .default, handler: { _ in
            music.library.setLiked(track, !liked)
        }))
        sheet.addAction(UIAlertAction(title: strings.moko("Отправить в чат"), style: .default, handler: { [weak controller] _ in
            let selection = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyWriteable, .excludeDisabled]))
            selection.peerSelected = { [weak selection] peer, threadId in
                selection?.dismiss()
                toast(context, strings.moko("Отправляю…"))
                let _ = (MokoTrackSending.send(context: context, track: track, peerId: peer.id, threadId: threadId)
                |> deliverOnMainQueue).start(error: { error in
                    if case let .download(error) = error {
                        toast(context, errorText(error, strings: strings))
                    }
                }, completed: {
                    toast(context, strings.moko("Отправлено"))
                })
            }
            controller?.push(selection)
        }))
        sheet.addAction(UIAlertAction(title: strings.moko("Добавить в профиль"), style: .default, handler: { _ in
            toast(context, strings.moko("Добавляю в профиль…"))
            let _ = (MokoTrackSending.addToProfile(context: context, track: track)
            |> deliverOnMainQueue).start(error: { error in
                switch error {
                case let .download(error):
                    toast(context, errorText(error, strings: strings))
                case .notDelivered, .profile:
                    toast(context, strings.moko("Не получилось добавить в профиль. Трек остался в «Избранном»."))
                }
            }, completed: {
                toast(context, strings.moko("Добавлено в профиль"))
            })
        }))
        sheet.addAction(UIAlertAction(title: strings.moko("Сохранить в Файлы"), style: .default, handler: { _ in
            let _ = (music.downloader.download(track)
            |> deliverOnMainQueue).start(next: { url in
                let named = FileManager.default.temporaryDirectory.appendingPathComponent("\(track.artist) - \(track.title).\(track.fileExtension)".replacingOccurrences(of: "/", with: "_"))
                try? FileManager.default.removeItem(at: named)
                try? FileManager.default.copyItem(at: url, to: named)
                presentNative(context, UIActivityViewController(activityItems: [named], applicationActivities: nil))
            }, error: { error in
                toast(context, errorText(error, strings: strings))
            })
        }))
        if !track.permalink.isEmpty {
            sheet.addAction(UIAlertAction(title: strings.moko("Копировать ссылку"), style: .default, handler: { _ in
                UIPasteboard.general.string = track.permalink
                toast(context, strings.moko("Ссылка скопирована"))
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.moko("Отмена"), style: .cancel))
        presentNative(context, sheet)
    }

    /// Desktop's error wording for SoundCloud failures.
    public static func errorText(_ error: MokoMusicError, strings: PresentationStrings) -> String {
        switch error {
        case .noClientId:
            return strings.moko("не удалось получить client_id SoundCloud")
        case .clientIdExpired:
            return strings.moko("client_id SoundCloud устарел")
        case let .network(status):
            return strings.moko("сеть: %1 (код %2)", status == 0 ? strings.moko("нет соединения") : "HTTP", "\(status)")
        case .unavailable:
            return strings.moko("трек недоступен (закрыт или удалён)")
        case .noStreamUrl:
            return strings.moko("нет ссылки на поток")
        case .emptyPlaylist:
            return strings.moko("пустой плейлист")
        case .segmentFailed:
            return strings.moko("сбой загрузки сегмента")
        case .writeFailed:
            return strings.moko("не удалось записать файл")
        }
    }
}
