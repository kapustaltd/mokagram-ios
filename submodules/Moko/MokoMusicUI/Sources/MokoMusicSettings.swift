import Foundation
import Display
import SwiftSignalKit
import AccountContext
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
                music.downloader.clear(protecting: playing.map { [$0] } ?? [])
                MokoTrackActions.toast(context, context.sharedContext.currentPresentationData.with { $0 }.strings.moko("Кэш музыки очищен"))
            })
        }))
    }
}
