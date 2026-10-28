import Foundation

/// The settings mokaGram registers itself. Keys, Russian titles and defaults follow Desktop
/// (`Telegram/SourceFiles/mokagram/ghost/mokagram_ghost.cpp`, `commands/mokagram_commands.cpp`);
/// descriptions state what the iOS implementation actually covers.
public enum MokoBuiltinSettings {
    private static let ghost = "Призрак"
    private static let schedule = "По расписанию"
    private static let commands = "Быстрые команды"
    private static let player = "Плеер"
    private static let saveinator = "Скачивание по ссылкам"

    private static func ghostFlag(_ key: String, _ title: String, _ description: String, defaultValue: Bool = true, dependsOn: String = "ghost.enabled", section: String = MokoBuiltinSettings.ghost, hidden: Bool = false) -> MokoSettingEntry {
        return MokoSettingEntry(key: key, page: .privacy, section: section, title: title, description: description, kind: .bool, defaultValue: .bool(defaultValue), scope: .account, dependsOn: dependsOn, hidden: hidden)
    }

    private static let streamer = "Режим стримера"

    private static func streamerFlag(_ key: String, _ title: String, _ description: String, _ defaultValue: Bool) -> MokoSettingEntry {
        return MokoSettingEntry(key: key, page: .privacy, section: streamer, title: title, description: description, kind: .bool, defaultValue: .bool(defaultValue), scope: .device, dependsOn: "streamer.enabled")
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
        // Streamer mode: device-wide, since it protects the screen rather than an account.
        MokoSettingEntry(key: "streamer.enabled", page: .privacy, section: streamer, title: "Режим стримера", description: "Прячет ваш номер, юзернейм и ID на экране, чтобы их не увидели зрители.", kind: .bool, defaultValue: .bool(false), scope: .device),
        streamerFlag("streamer.phone", "Номер телефона", "Ваш номер в настройках, профиле и меню.", true),
        streamerFlag("streamer.username", "Юзернейм", "Ваш @юзернейм там, где он показан.", true),
        streamerFlag("streamer.link", "Ссылки на ваш профиль", "Адреса вида t.me/ваш_ник.", true),
        streamerFlag("streamer.id", "Числовой ID", "Служебный номер вашего аккаунта.", true),
        streamerFlag("streamer.name", "Имя и фамилия", "Только ваши: в профиле, меню и настройках. Чужие имена в чатах не трогаем.", false),
        streamerFlag("streamer.notify", "Текст уведомлений", "Во всплывающих уведомлениях не видно, кто написал и что именно.", false),
        MokoSettingEntry(key: "streamer.copy", page: .privacy, section: streamer, title: "Что копировать со скрытым", description: "Что попадёт в буфер обмена, если скопировать спрятанное значение.", kind: .choice(["Настоящее значение", "Ничего", "Точки"]), defaultValue: .int(0), scope: .device, dependsOn: "streamer.enabled"),
        MokoSettingEntry(key: "commands.enabled", page: .tools, section: commands, title: "Быстрые команды", description: "Команды: .calc, .id, .snip, .tag, .note, .archive, .unarchive, .mute, .unmute и .save. Они выполняются на телефоне и не отправляются в чат.", kind: .bool, defaultValue: .bool(false), scope: .account),
        // Music: device-wide, as on Desktop (appearance/mokagram_appearance.cpp:187-212).
        MokoSettingEntry(key: "player.autoplay_next", page: .music, section: player, title: "Автовоспроизведение следующего", description: "Когда трек заканчивается, начинается следующий в очереди.", kind: .bool, defaultValue: .bool(true), scope: .device),
        MokoSettingEntry(key: "player.cover_colors", page: .music, section: player, title: "Цвета плеера из обложки", description: "", kind: .bool, defaultValue: .bool(true), scope: .device, hidden: true),
        MokoSettingEntry(key: "lyrics.enabled", page: .music, section: player, title: "Текст песни", description: "Тексты берутся из LRCLIB, а если там нет, из NetEase.", kind: .bool, defaultValue: .bool(true), scope: .device),
        MokoSettingEntry(key: "music.cache_mb", page: .music, section: player, title: "Кэш музыки, МБ", description: "Скачанные треки SoundCloud. Самые старые удаляются, когда кэш больше этого размера.", kind: .int(min: 100, max: 5000), defaultValue: .int(500), scope: .device),
        // Saveinator: device-wide, as on Desktop (saveinator/mokagram_saveinator.cpp).
        MokoSettingEntry(key: "saveinator.enabled", page: .chats, section: saveinator, title: "Скачивание видео и музыки по ссылкам", description: "Если отправить только ссылку на YouTube, TikTok, X, Instagram, Reddit, Pinterest, VK, Spotify, SoundCloud или Яндекс Музыку, клиент предложит скачать видео, фото или трек и отправить файл вместо ссылки.", kind: .bool, defaultValue: .bool(true), scope: .device),
        MokoSettingEntry(key: "saveinator.media", page: .chats, section: saveinator, title: "Формат скачивания", description: "", kind: .int(min: 0, max: 3), defaultValue: .int(0), scope: .device, hidden: true),
        MokoSettingEntry(key: "saveinator.quality", page: .chats, section: saveinator, title: "Качество скачивания", description: "", kind: .int(min: 0, max: 4), defaultValue: .int(2), scope: .device, hidden: true),
        MokoSettingEntry(key: "commands.aliases", page: .tools, section: commands, title: "Алиасы команд", description: "", kind: .string, defaultValue: .string(""), scope: .account, dependsOn: "commands.enabled", hidden: true),
    ]
}
