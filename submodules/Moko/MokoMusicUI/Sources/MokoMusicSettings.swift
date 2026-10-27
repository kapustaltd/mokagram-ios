import Foundation
import Display
import SwiftSignalKit
import AccountContext
import TelegramCore
import MokoCore
import MokoSettingsUI

/// The music rows of the mokaGram settings page. Call once before the settings screen opens.
public enum MokoMusicSettings {
    private static var registered = false

    public static func register() {
        guard !registered else {
            return
        }
        registered = true
        MokoSettingsCustomRows.register(MokoSettingsCustomRow(page: .music, section: "Музыка", title: "Музыка", open: { context, controller in
            controller.push(mokoMusicController(context: context, initialQuery: nil))
        }))
        MokoSettingsCustomRows.register(MokoSettingsCustomRow(page: .music, section: "Плеер", title: "Очистить кэш музыки", open: { context, _ in
            let music = MokoMusicContext.shared
            let _ = (music.currentQueue |> take(1)).start(next: { queue in
                let playing = queue?.current.flatMap { music.downloader.cachedFile(for: $0) }
                // Playing a local file copies it into the account's media box; drop those copies too.
                let copies = music.downloader.cachedTrackIds().filter { id in playing?.deletingPathExtension().lastPathComponent != id }.map { id in
                    return EngineMediaResource.Id(LocalFileReferenceMediaResource(localFilePath: "", randomId: MokoMusicContext.fileId(forTrackId: id)).id)
                }
                music.downloader.clear(protecting: playing.map { [$0] } ?? [])
                let _ = context.engine.resources.removeCachedResources(ids: copies).start()
                MokoTrackActions.toast(context, context.sharedContext.currentPresentationData.with { $0 }.strings.moko("Кэш музыки очищен"))
            })
        }))
    }
}
