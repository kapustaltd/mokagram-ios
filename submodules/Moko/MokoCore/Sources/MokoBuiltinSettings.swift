import Foundation

/// The settings mokaGram registers itself. Keys, Russian titles and defaults follow Desktop
/// (`Telegram/SourceFiles/mokagram/ghost/mokagram_ghost.cpp`, `commands/mokagram_commands.cpp`);
/// descriptions state what the iOS implementation actually covers.
public enum MokoBuiltinSettings {
    private static let ghost = "Призрак"
    private static let schedule = "По расписанию"
    private static let commands = "Быстрые команды"

    private static func ghostFlag(_ key: String, _ title: String, _ description: String, defaultValue: Bool = true, dependsOn: String = "ghost.enabled", section: String = MokoBuiltinSettings.ghost, hidden: Bool = false) -> MokoSettingEntry {
        return MokoSettingEntry(key: key, page: .privacy, section: section, title: title, description: description, kind: .bool, defaultValue: .bool(defaultValue), scope: .account, dependsOn: dependsOn, hidden: hidden)
    }

    public static let entries: [MokoSettingEntry] = [
        MokoSettingEntry(key: "ghost.enabled", page: .privacy, section: ghost, title: "Призрак", description: "Вы читаете чаты, а собеседники не видят, что вы были в сети и прочитали.", kind: .bool, defaultValue: .bool(false), scope: .account),
        ghostFlag("ghost.read", "Не отмечать прочитанным", "Останавливает автоматическую отметку при просмотре чатов и обсуждений. Ручная отметка, уведомления, прослушивание медиа и другие устройства могут отправить прочтение."),
        ghostFlag("ghost.online", "Скрывать, что я в сети", "Приложение отправит запрос о выходе из сети и перестанет обновлять статус. Другие устройства и действия в Telegram могут раскрыть вашу активность."),
        ghostFlag("ghost.typing", "Скрывать «печатает»", "Не отправлять статусы набора, записи и загрузки с этого устройства. На другие устройства и статус «в сети» настройка не влияет."),
        ghostFlag("ghost.stories", "Скрывать просмотр историй", "Действует только на этом устройстве и не отменяет уже отправленные просмотры. Реакции и ответы могут раскрыть просмотр. После отключения просмотр новых историй может отметить предыдущие как просмотренные."),
        // Stored for .mokaset compatibility. iOS always sends offline when online updates are suppressed.
        ghostFlag("ghost.offline_on_enable", "Выйти из сети при включении", "Сразу после включения Призрака один раз сообщаем, что вас нет в сети.", hidden: true),
        MokoSettingEntry(key: "ghost.schedule", page: .privacy, section: schedule, title: "Включать по расписанию", description: "В эти часы к обычным настройкам Призрака добавляется выбранное ниже. Окно может переходить через полночь.", kind: .bool, defaultValue: .bool(false), scope: .account),
        MokoSettingEntry(key: "ghost.schedule_from", page: .privacy, section: schedule, title: "С", description: "", kind: .string, defaultValue: .string("23:00"), scope: .account, dependsOn: "ghost.schedule"),
        MokoSettingEntry(key: "ghost.schedule_to", page: .privacy, section: schedule, title: "До", description: "", kind: .string, defaultValue: .string("07:00"), scope: .account, dependsOn: "ghost.schedule"),
        ghostFlag("ghost.sched_read", "Не отмечать прочитанным", "", dependsOn: "ghost.schedule", section: schedule),
        ghostFlag("ghost.sched_online", "Скрыть «в сети»", "", dependsOn: "ghost.schedule", section: schedule),
        ghostFlag("ghost.sched_typing", "Не показывать «печатает»", "", dependsOn: "ghost.schedule", section: schedule),
        ghostFlag("ghost.sched_stories", "Скрыть просмотры историй", "", defaultValue: false, dependsOn: "ghost.schedule", section: schedule),
        MokoSettingEntry(key: "commands.enabled", page: .tools, section: commands, title: "Быстрые команды", description: "Команды: .calc, .id, .snip, .tag, .note, .archive, .unarchive, .mute, .unmute и .save. Они выполняются на телефоне и не отправляются в чат.", kind: .bool, defaultValue: .bool(false), scope: .account),
        MokoSettingEntry(key: "commands.aliases", page: .tools, section: commands, title: "Алиасы команд", description: "", kind: .string, defaultValue: .string(""), scope: .account, dependsOn: "commands.enabled", hidden: true),
    ]
}
