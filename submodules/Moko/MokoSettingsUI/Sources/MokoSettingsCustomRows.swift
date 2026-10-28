import Foundation
import Display
import AccountContext
import MokoCore

/// A row a feature adds to a settings page next to the registry entries (Snippets, Music…).
public struct MokoSettingsCustomRow {
    public let page: MokoSettingPage
    /// Russian group title, as in `MokoSettingEntry.section`.
    public let section: String
    /// Russian row text.
    public let title: String
    public let open: (AccountContext, ViewController) -> Void

    public init(page: MokoSettingPage, section: String, title: String, open: @escaping (AccountContext, ViewController) -> Void) {
        self.page = page
        self.section = section
        self.title = title
        self.open = open
    }
}

public enum MokoSettingsCustomRows {
    private static var registered: [MokoSettingsCustomRow] = [
        MokoSettingsCustomRow(page: .tools, section: "Быстрые команды", title: "Алиасы команд", open: { context, controller in
            guard let presenter = controller.view.window?.rootViewController else {
                return
            }
            let isRussian = MokoStrings.isRussianFamily(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
            MokoSnippetSettings.showAliases(presenter: presenter, accountId: context.account.peerId.toInt64(), isRussian: isRussian)
        }),
        MokoSettingsCustomRow(page: .tools, section: "Сниппеты", title: "Сниппеты", open: { context, controller in
            guard let presenter = controller.view.window?.rootViewController else {
                return
            }
            let isRussian = MokoStrings.isRussianFamily(languageCode: context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode)
            MokoSnippetSettings.show(presenter: presenter, accountId: context.account.peerId.toInt64(), isRussian: isRussian)
        }),
    ]

    /// Main thread only.
    public static func register(_ row: MokoSettingsCustomRow) {
        registered.append(row)
    }

    static func rows(page: MokoSettingPage) -> [MokoSettingsCustomRow] {
        return registered.filter { $0.page == page }
    }
}
