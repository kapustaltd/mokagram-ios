import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import LegacyMediaPickerUI
import UndoUI
import MokoCore

private enum MokoRowAction: Equatable {
    case openPage(MokoSettingPage)
    case edit(String)
    case custom(page: MokoSettingPage, index: Int)
    case export
    case importFile
    case resetAll
    case resetPage(MokoSettingPage)
    case url(String)
}

private final class MokoSettingsArguments {
    let toggle: (String, Bool) -> Void
    let perform: (MokoRowAction) -> Void

    init(toggle: @escaping (String, Bool) -> Void, perform: @escaping (MokoRowAction) -> Void) {
        self.toggle = toggle
        self.perform = perform
    }
}

private enum MokoSettingsRow: ItemListNodeEntry {
    case header(id: Int32, section: Int32, text: String)
    case toggle(id: Int32, section: Int32, key: String, title: String, value: Bool, enabled: Bool)
    case disclosure(id: Int32, section: Int32, title: String, label: String, enabled: Bool, action: MokoRowAction)
    case button(id: Int32, section: Int32, title: String, destructive: Bool, action: MokoRowAction)
    case footer(id: Int32, section: Int32, text: String)

    var section: ItemListSectionId {
        switch self {
        case let .header(_, section, _), let .toggle(_, section, _, _, _, _), let .disclosure(_, section, _, _, _, _), let .button(_, section, _, _, _), let .footer(_, section, _):
            return section
        }
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _, _), let .toggle(id, _, _, _, _, _), let .disclosure(id, _, _, _, _, _), let .button(id, _, _, _, _), let .footer(id, _, _):
            return id
        }
    }

    static func <(lhs: MokoSettingsRow, rhs: MokoSettingsRow) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! MokoSettingsArguments
        switch self {
        case let .header(_, _, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, _, key, title, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .disclosure(_, _, title, label, enabled, action):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, enabled: enabled, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.perform(action)
            })
        case let .button(_, _, title, destructive, action):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: destructive ? .destructive : .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.perform(action)
            })
        case let .footer(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// Builds rows with increasing ids and section numbers.
private struct MokoRowBuilder {
    var rows: [MokoSettingsRow] = []
    private var nextId: Int32 = 0
    private(set) var section: Int32 = 0

    mutating func id() -> Int32 {
        defer { nextId += 1 }
        return nextId
    }

    mutating func newSection() {
        section += 1
    }

    mutating func add(_ make: (Int32, Int32) -> MokoSettingsRow) {
        let row = make(id(), section)
        rows.append(row)
    }
}

private func mokoPageTitle(_ page: MokoSettingPage) -> String {
    switch page {
    case .privacy:
        return "Приватность"
    case .security:
        return "Безопасность"
    case .history:
        return "Удалёнки"
    case .chats:
        return "Чаты"
    case .music:
        return "Музыка"
    case .tools:
        return "Инструменты"
    case .system:
        return "Система"
    }
}

/// Keys whose String value is a "HH:mm" time.
private let mokoTimeKeys: Set<String> = ["ghost.schedule_from", "ghost.schedule_to"]

private func mokoVisibleEntries(page: MokoSettingPage) -> [MokoSettingEntry] {
    // Action entries carry no handler in the registry; features add buttons as custom rows.
    return MokoSettings.entries().filter { $0.page == page && !$0.hidden && $0.kind != .action }
}

private func mokoValueLabel(_ entry: MokoSettingEntry, accountId: Int64, strings: PresentationStrings) -> String {
    switch MokoSettings.value(entry.key, accountId: accountId) {
    case let .int(value)?:
        if case let .choice(captions) = entry.kind, value >= 0, value < captions.count {
            return strings.moko(captions[value])
        }
        return "\(value)"
    case let .string(value)?:
        return value
    default:
        return ""
    }
}

private func mokoChangedTitle(_ title: String, changed: Bool) -> String {
    return changed ? "\(title) •" : title
}

private func mokoPageRows(page: MokoSettingPage, accountId: Int64, strings: PresentationStrings, needsRestart: Bool) -> [MokoSettingsRow] {
    var builder = MokoRowBuilder()
    var sections: [String] = []
    var bySection: [String: [Any]] = [:]
    for entry in mokoVisibleEntries(page: page) {
        if bySection[entry.section] == nil {
            sections.append(entry.section)
        }
        bySection[entry.section, default: []].append(entry)
    }
    for (index, row) in MokoSettingsCustomRows.rows(page: page).enumerated() {
        if bySection[row.section] == nil {
            sections.append(row.section)
        }
        bySection[row.section, default: []].append((index, row))
    }
    if needsRestart {
        builder.add { .header(id: $0, section: $1, text: strings.moko("Нужен перезапуск")) }
        builder.add { .footer(id: $0, section: $1, text: strings.moko("Часть изменений заработает после перезапуска приложения.")) }
        builder.newSection()
    }
    for section in sections {
        var first = true
        for item in bySection[section] ?? [] {
            if first {
                builder.add { .header(id: $0, section: $1, text: strings.moko(section)) }
                first = false
            }
            if let entry = item as? MokoSettingEntry {
                let enabled = entry.dependsOn.map { MokoSettings.bool($0, accountId: accountId) } ?? true
                let title = mokoChangedTitle(strings.moko(entry.title), changed: MokoSettings.isChanged(entry.key, accountId: accountId))
                if case .bool = entry.kind {
                    builder.add { .toggle(id: $0, section: $1, key: entry.key, title: title, value: MokoSettings.bool(entry.key, accountId: accountId), enabled: enabled) }
                } else {
                    builder.add { .disclosure(id: $0, section: $1, title: title, label: mokoValueLabel(entry, accountId: accountId, strings: strings), enabled: enabled, action: .edit(entry.key)) }
                }
                if !entry.description.isEmpty {
                    builder.add { .footer(id: $0, section: $1, text: strings.moko(entry.description)) }
                    // Each described row is its own block so its footer sits under it; the
                    // group header is shown once, above the first block.
                    builder.newSection()
                }
            } else if let (index, row) = item as? (Int, MokoSettingsCustomRow) {
                builder.add { .disclosure(id: $0, section: $1, title: strings.moko(row.title), label: "", enabled: true, action: .custom(page: page, index: index)) }
            }
        }
        builder.newSection()
    }
    builder.add { .button(id: $0, section: $1, title: strings.moko("Сбросить страницу"), destructive: true, action: .resetPage(page)) }
    builder.add { .footer(id: $0, section: $1, text: strings.moko("Изменённые значения отмечены точкой.")) }
    return builder.rows
}

private func mokoRootRows(accountId: Int64, strings: PresentationStrings) -> [MokoSettingsRow] {
    var builder = MokoRowBuilder()
    builder.add { .header(id: $0, section: $1, text: strings.moko("Настройки mokaGram")) }
    for page in MokoSettingPage.allCases {
        let entries = mokoVisibleEntries(page: page)
        guard !entries.isEmpty || !MokoSettingsCustomRows.rows(page: page).isEmpty else {
            continue
        }
        let changed = entries.filter { MokoSettings.isChanged($0.key, accountId: accountId) }.count
        builder.add { .disclosure(id: $0, section: $1, title: strings.moko(mokoPageTitle(page)), label: changed > 0 ? "\(changed)" : "", enabled: true, action: .openPage(page)) }
    }
    builder.newSection()
    builder.add { .header(id: $0, section: $1, text: strings.moko("Перенос")) }
    builder.add { .disclosure(id: $0, section: $1, title: strings.moko("Экспорт настроек"), label: "", enabled: true, action: .export) }
    builder.add { .disclosure(id: $0, section: $1, title: strings.moko("Импорт настроек"), label: "", enabled: true, action: .importFile) }
    builder.newSection()
    builder.add { .button(id: $0, section: $1, title: strings.moko("Сбросить всё"), destructive: true, action: .resetAll) }
    builder.newSection()
    builder.add { .header(id: $0, section: $1, text: strings.moko("О mokaGram")) }
    builder.add { .disclosure(id: $0, section: $1, title: strings.moko("Основано на mokaGram, автор @ecronx"), label: "", enabled: true, action: .url("https://t.me/ecronx")) }
    builder.add { .disclosure(id: $0, section: $1, title: strings.moko("Исходный код mokaGram"), label: "", enabled: true, action: .url("https://github.com/ecronxy/mokagram")) }
    return builder.rows
}

/// Fires once now and on every registry change.
private func mokoSettingsChanges() -> Signal<Void, NoError> {
    return Signal { subscriber in
        subscriber.putNext(Void())
        let observer = NotificationCenter.default.addObserver(forName: MokoSettings.didChange, object: nil, queue: .main, using: { _ in
            subscriber.putNext(Void())
        })
        return ActionDisposable {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

private func mokoPresentNative(_ context: AccountContext, _ controller: UIViewController) {
    if let window = context.sharedContext.applicationBindings.getTopWindow(), let popover = controller.popoverPresentationController {
        popover.sourceView = window
        popover.sourceRect = CGRect(origin: CGPoint(x: window.bounds.width / 2.0, y: window.bounds.height - 1.0), size: CGSize(width: 1.0, height: 1.0))
    }
    context.sharedContext.applicationBindings.presentNativeController(controller)
}

/// Asks for a new value of a non-Bool entry and stores it.
private func mokoEditEntry(context: AccountContext, entry: MokoSettingEntry, accountId: Int64, showError: @escaping (String) -> Void) {
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    let title = strings.moko(entry.title)
    switch entry.kind {
    case let .choice(captions):
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for (index, caption) in captions.enumerated() {
            sheet.addAction(UIAlertAction(title: strings.moko(caption), style: .default, handler: { _ in
                MokoSettings.set(.int(index), for: entry.key, accountId: accountId)
            }))
        }
        sheet.addAction(UIAlertAction(title: strings.moko("Отмена"), style: .cancel))
        mokoPresentNative(context, sheet)
    case .int, .string, .color:
        var hint = entry.description.isEmpty ? nil : strings.moko(entry.description)
        if case let .int(minValue, maxValue) = entry.kind {
            hint = strings.moko("Число от %1 до %2", "\(minValue)", "\(maxValue)")
        } else if entry.kind == .color {
            hint = strings.moko("Цвет в формате #RRGGBB")
        } else if mokoTimeKeys.contains(entry.key) {
            hint = strings.moko("Время в формате ЧЧ:ММ")
        }
        let alert = UIAlertController(title: title, message: hint, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = mokoValueLabel(entry, accountId: accountId, strings: strings)
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            if case .int = entry.kind {
                field.keyboardType = .numberPad
            }
        }
        alert.addAction(UIAlertAction(title: strings.moko("Отмена"), style: .cancel))
        alert.addAction(UIAlertAction(title: strings.moko("Сохранить"), style: .default, handler: { [weak alert] _ in
            let text = (alert?.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            switch entry.kind {
            case let .int(minValue, maxValue):
                guard let value = Int(text), value >= minValue, value <= maxValue else {
                    showError(hint ?? "")
                    return
                }
                MokoSettings.set(.int(value), for: entry.key, accountId: accountId)
            case .color:
                guard text.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil || text.isEmpty else {
                    showError(hint ?? "")
                    return
                }
                MokoSettings.set(.string(text.lowercased()), for: entry.key, accountId: accountId)
            default:
                if mokoTimeKeys.contains(entry.key), MokoGhostSchedule.parseTime(text) == nil {
                    showError(hint ?? "")
                    return
                }
                MokoSettings.set(.string(text), for: entry.key, accountId: accountId)
            }
        }))
        mokoPresentNative(context, alert)
    case .bool, .action:
        break
    }
}

private func mokoImportErrorText(_ error: MokoSettingsFileError, strings: PresentationStrings) -> String {
    switch error {
    case .notJson:
        return strings.moko("Файл не похож на набор настроек.")
    case .notMokaset:
        return strings.moko("Это не файл .mokaset.")
    case .newerVersion:
        return strings.moko("Файл сделан более новой версией mokaGram.")
    case .noValues:
        return strings.moko("В файле нет значений.")
    }
}

private func mokoSettingsListController(context: AccountContext, page: MokoSettingPage?) -> ViewController {
    let accountId = context.account.peerId.toInt64()
    let needsRestart = ValuePromise<Bool>(false, ignoreRepeated: true)
    var controllerRef: (() -> ViewController?)?

    let present: (ViewController) -> Void = { presented in
        controllerRef?()?.present(presented, in: .window(.root))
    }
    let alert: (String?, String) -> Void = { title, text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        present(textAlertController(context: context, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }
    let toast: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controllerRef?()?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }

    let arguments = MokoSettingsArguments(toggle: { key, value in
        MokoSettings.set(.bool(value), for: key, accountId: accountId)
        if MokoSettings.entry(key)?.requiresRestart == true {
            needsRestart.set(true)
        }
    }, perform: { action in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        switch action {
        case let .openPage(page):
            controllerRef?()?.push(mokoSettingsListController(context: context, page: page))
        case let .edit(key):
            guard let entry = MokoSettings.entry(key) else {
                return
            }
            mokoEditEntry(context: context, entry: entry, accountId: accountId, showError: { hint in
                alert(strings.moko("Неверное значение"), hint)
            })
            if entry.requiresRestart {
                needsRestart.set(true)
            }
        case let .custom(page, index):
            let rows = MokoSettingsCustomRows.rows(page: page)
            if index < rows.count, let controller = controllerRef?() {
                rows[index].open(context, controller)
            }
        case .export:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("mokagram-\(formatter.string(from: Date())).mokaset")
            let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "ios"
            do {
                try MokoSettingsFile.export(accountId: accountId, appVersion: "\(version)-moka-ios").write(to: url, options: .atomic)
            } catch {
                return
            }
            mokoPresentNative(context, UIActivityViewController(activityItems: [url], applicationActivities: nil))
        case .importFile:
            let picker = legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["public.item"], completion: { urls in
                guard let url = urls.first else {
                    return
                }
                let accessed = url.startAccessingSecurityScopedResource()
                let data = try? Data(contentsOf: url)
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
                guard let data else {
                    alert(nil, strings.moko("Файл не удалось прочитать."))
                    return
                }
                switch MokoSettingsFile.preview(data, accountId: accountId) {
                case let .failure(error):
                    alert(nil, mokoImportErrorText(error, strings: strings))
                case let .success(summary):
                    let text = strings.moko("Изменится значений: %1. Неизвестных ключей: %2 (сохранятся). Неверных значений: %3 (пропустятся).", "\(summary.changed)", "\(summary.unknown)", "\(summary.invalid)")
                    present(textAlertController(context: context, title: strings.moko("Импортировать настройки?"), text: text, actions: [
                        TextAlertAction(type: .genericAction, title: strings.moko("Отмена"), action: {}),
                        TextAlertAction(type: .defaultAction, title: strings.moko("Применить"), action: {
                            if case .success = MokoSettingsFile.apply(data, accountId: accountId) {
                                toast(strings.moko("Настройки импортированы"))
                            }
                        }),
                    ]))
                }
            })
            present(picker)
        case .resetAll:
            present(textAlertController(context: context, title: strings.moko("Сбросить все настройки mokaGram?"), text: strings.moko("Значения этого аккаунта и устройства вернутся к значениям по умолчанию. Заметки, сниппеты и исключения останутся."), actions: [
                TextAlertAction(type: .genericAction, title: strings.moko("Отмена"), action: {}),
                TextAlertAction(type: .destructiveAction, title: strings.moko("Сбросить"), action: {
                    MokoSettings.resetAll(accountId: accountId)
                }),
            ]))
        case let .resetPage(page):
            MokoSettings.reset(page: page, accountId: accountId)
        case let .url(url):
            context.sharedContext.applicationBindings.openUrl(url)
        }
    })

    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, mokoSettingsChanges(), needsRestart.get())
    |> map { presentationData, _, needsRestart -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let strings = presentationData.strings
        let title = page.map { strings.moko(mokoPageTitle($0)) } ?? "mokaGram"
        let rows = page.map { mokoPageRows(page: $0, accountId: accountId, strings: strings, needsRestart: needsRestart) } ?? mokoRootRows(accountId: accountId, strings: strings)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: rows, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerRef = { [weak controller] in
        return controller
    }
    return controller
}

/// The "mokaGram" screen in Settings: one row per page, transfer, reset and attribution.
public func mokoSettingsController(context: AccountContext) -> ViewController {
    return mokoSettingsListController(context: context, page: nil)
}

public func mokoSettingsPageController(context: AccountContext, page: MokoSettingPage) -> ViewController {
    return mokoSettingsListController(context: context, page: page)
}
