# mokaGram iOS, фаза 0: основа — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Закрепить уже сделанное. Дать всем функциям mokaGram общий реестр настроек в группе
приложения, свою таблицу строк, экран «mokaGram» в Настройках и подписанную сборку в CI.

**Architecture:** Новый модуль `submodules/Moko/MokoCore` только на Foundation (+ SwiftSignalKit).
В нём хранилище в группе приложения, реестр настроек с ключами Desktop, файл `.mokaset` и таблица
строк. Модуль тестируется на хосте (`swift_test`) за секунды. `TelegramCore` и UI зависят от него.
Новый модуль `submodules/Moko/MokoSettingsUI` рисует экран настроек прямо по записям реестра,
как «Кастомизация» на Desktop: функции не пишут свои экраны настроек.

**Tech Stack:** Swift 6.4, Bazel (rules_swift `swift_test`, rules_apple `ios_unit_test`),
ItemListUI, SwiftSignalKit, Python 3 для скриптов сборки.

**Spec:** `openspec/changes/port-mokagram-desktop/design.md` (разделы 3, 6 фаза 0, 7).

## Global Constraints

- Все функции mokaGram выключены по умолчанию; ключи настроек совпадают с Desktop (`ghost.read`, `commands.enabled`, …).
- Файл `.mokaset`: `{"format":"mokaset","app":<строка>,"version":1,"values":{ключ: значение}}`, пишутся только отличия от умолчаний; файл с `version` > 1 отклоняется.
- Хранилище: `UserDefaults(suiteName: "group.<baseAppBundleId>")`; в хосте тестов и при недоступной группе используется переданный в `configure` экземпляр.
- Строки: для языков `ru`, `uk`, `be` русский текст как есть, для остальных английский перевод, а если его нет, русский.
- `TelegramCore` не импортирует UIKit/Display; новые модули не добавляют `import Postbox`.
- Новые библиотеки Swift собираются с `copts = ["-warnings-as-errors"]`.
- Хост-тест: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/Moko/MokoCore:MokoCoreTests --test_output=errors`.
- Полная сборка: `CONFIGURATION=debug_sim_arm64 build-system/mokagram/build-local.sh` (заглушка подписи, как в CI).
- Тесты в симуляторе: `build-system/mokagram/test-local.sh //submodules/TelegramCore:TelegramCoreTests` (скрипт из Task 1).
- Сообщения коммитов заканчиваются строкой `Claude-Session: https://claude.ai/code/session_017fhth1mtnEWVANtNj4DtQp`.

## Review Focus

- Пользователь включал на iOS «Скрывать действия в чате» до обновления. После миграции «Призрак» должен остаться включённым именно для этой функции, остальные не включаются (тест `testMigratesLegacyTypingFlag`, Task 4).
- Импорт `.mokaset` с Desktop, где `ghost.enabled = false`, а подфлаги `true` по умолчанию, не должен включить скрытие прочтения (тест `testImportDesktopDefaultsKeepsGhostOff`, Task 3).
- В файле ключи, которых iOS не знает (`lag.level`, `plugin.x.y`), и значения неверного типа. Предпросмотр считает их `unknown` и `invalid`, импорт их пропускает, но неизвестные сохраняет, чтобы их увидел будущий плагин (тест `testPreviewCountsUnknownAndInvalid`, Task 3).
- Два аккаунта на одном устройстве: настройка аккаунта A не видна у B, а настройка устройства видна у обоих (тест `testAccountScopeIsolation`, Task 2).
- Расширение уведомлений читает те же значения, что и приложение (проверка на устройстве в Task 6).

---

### Task 1: Закрепить начатую работу

На ветке `main` лежат незакоммиченные изменения: 57 файлов плюс новые `Moko*.swift` с тестами.
Сначала они должны собираться и проходить тесты, и только потом на них строится остальное.

**Files:**
- Create: `build-system/mokagram/test-local.sh`
- Modify: ничего из уже изменённого, если сборка проходит

**Interfaces:**
- Produces: `build-system/mokagram/test-local.sh <bazel label>`. Он делает то же, что
  `build-local.sh` (prepare.py, временная связка ключей с заглушкой), но вызывает
  `Make.py test --target <label>` вместо `build`.

- [ ] **Step 1: Создать ветку** `git checkout -b moko/phase0`.
- [ ] **Step 2: Написать `test-local.sh`** по образцу `build-local.sh`: тот же `cleanup`, тот же
  импорт `Placeholder.p12`, затем
  `python3 -u build-system/Make/Make.py --overrideXcodeVersion --cacheDir="$HOME/telegram-bazel-cache" test --configurationPath=build-input/mokagram/configuration.json --codesigningInformationPath=build-input/mokagram/signing --target "$1"`.
- [ ] **Step 3: Полная сборка.** Команда из Global Constraints. Ожидается `Build completed successfully`.
  Ошибки компиляции в незакоммиченных файлах исправить минимально, не меняя поведения.
- [ ] **Step 4: Тесты.** `build-system/mokagram/test-local.sh //submodules/TelegramCore:TelegramCoreTests`.
  Ожидается PASS всех `Moko*Tests`.
- [ ] **Step 5: Коммиты по смыслу**, каждый отдельно:
  1. ребрендинг (`Telegram/BUILD`, `*.lproj`, значки, README, `MOKAGRAM_NOTICE.md`, `RMIntro`);
  2. теги и заметки;
  3. «Призрак» (`ManagedAccountPresence`, `ManagedLocalInputActivities`, `Stories`, чтение);
  4. сниппеты и команды;
  5. информация о сообщении;
  6. OpenSpec, `build-local.sh` и `test-local.sh`, CI.

  В git не попадают `bazel-mokagram-ios`, `.agents/`, `.opencode/`: добавить их в `.gitignore`.

### Task 2: Модуль MokoCore: хранилище и реестр настроек

**Files:**
- Create: `submodules/Moko/MokoCore/BUILD` (`swift_library` `MokoCore` + `swift_test` `MokoCoreTests`, deps `//submodules/SSignalKit/SwiftSignalKit`)
- Create: `submodules/Moko/MokoCore/Sources/MokoStorage.swift`
- Create: `submodules/Moko/MokoCore/Sources/MokoSettings.swift`
- Create: `submodules/Moko/MokoCore/Sources/MokoBuiltinSettings.swift`
- Test: `submodules/Moko/MokoCore/Tests/MokoSettingsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum MokoStorage {
      public static func configure(appGroupName: String?, fallback: UserDefaults = .standard)
      public static var defaults: UserDefaults { get }   // группа, иначе fallback
      public static var containerURL: URL? { get }       // контейнер группы для файлов (музыка, база удалённых)
      static func reset(defaults: UserDefaults)           // только для тестов
  }
  public enum MokoSettingScope: Equatable { case account, device }
  public enum MokoSettingPage: String, CaseIterable { case privacy, security, history, chats, music, tools, system }
  public enum MokoSettingKind: Equatable {
      case bool
      case int(min: Int, max: Int)
      case choice([String])   // русские подписи, значение это индекс
      case string
      case color              // "#rrggbb"
      case action             // строка-кнопка, значение не хранится
  }
  public enum MokoSettingValue: Equatable { case bool(Bool), int(Int), string(String) }
  public struct MokoSettingEntry {
      public var key: String
      public var page: MokoSettingPage
      public var section: String        // русский заголовок группы
      public var title: String          // русский текст
      public var description: String
      public var kind: MokoSettingKind
      public var defaultValue: MokoSettingValue
      public var scope: MokoSettingScope
      public var dependsOn: String?     // ключ Bool, при false строка неактивна
      public var requiresRestart: Bool
      public var hidden: Bool
  }
  public enum MokoSettings {
      public static let didChange: Notification.Name     // userInfo: "key": String, "accountId": Int64?
      public static func register(_ entries: [MokoSettingEntry])
      public static func entries() -> [MokoSettingEntry]
      public static func entry(_ key: String) -> MokoSettingEntry?
      public static func bool(_ key: String, accountId: Int64) -> Bool
      public static func int(_ key: String, accountId: Int64) -> Int
      public static func string(_ key: String, accountId: Int64) -> String
      public static func set(_ value: MokoSettingValue, for key: String, accountId: Int64)
      public static func reset(_ key: String, accountId: Int64)
      public static func reset(page: MokoSettingPage, accountId: Int64)
      public static func resetAll(accountId: Int64)
      public static func isChanged(_ key: String, accountId: Int64) -> Bool
      public static func boolSignal(_ key: String, accountId: Int64) -> Signal<Bool, NoError>
  }
  ```
- Ключ хранения: для `.account` это `mokoGram.s.<accountId>.<key>`, для `.device` это
  `mokoGram.s.device.<key>`. Значение, равное умолчанию, не записывается (`set` удаляет ключ).
  У `.device` параметр `accountId` игнорируется.
- `MokoBuiltinSettings.entries` — статический список записей. `MokoSettings` регистрирует его
  лениво при первом обращении, так что любой читатель видит умолчания без явной инициализации.
  В этой задаче список содержит записи раздела «Призрак» с Desktop
  (`ghost/mokagram_ghost.cpp:355-441`):
  - `ghost.enabled` (false, без зависимости);
  - `ghost.read`, `ghost.online`, `ghost.typing`, `ghost.stories` (true, зависят от `ghost.enabled`);
  - `ghost.offline_on_enable` (true);
  - `ghost.schedule` (false), `ghost.schedule_from` ("23:00"), `ghost.schedule_to` ("07:00");
  - `ghost.sched_read`, `ghost.sched_online`, `ghost.sched_typing`, `ghost.sched_stories`
    (Desktop: true, true, true, false).

  На Desktop записи расписания `hidden`, потому что у них там свой экран. На iOS
  `hidden = false`: они показываются группой «По расписанию» (Task 6).

  Плюс `commands.enabled` (false) и `commands.aliases` (""). Страница `privacy` или `tools`, область
  `.account`, заголовки по-русски дословно с Desktop. Описания у ghost-строк — текущие
  iOS-пояснения из `PeerInfoSettingsItems.swift` (в них уже названы ограничения).

- [ ] **Step 1: Тесты** в `MokoSettingsTests.swift`. Перед каждым тестом свежий
  `UserDefaults(suiteName: "moko.test.\(UUID())")` и `MokoStorage.reset(defaults:)`.
  - `testDefaultsWithoutWrites`: `MokoSettings.bool("ghost.enabled", accountId: 1) == false`,
    `bool("ghost.read", accountId: 1) == true`, `string("ghost.schedule_from", accountId: 1) == "23:00"`.
  - `testSettingDefaultRemovesKey`: `set(.bool(true), for: "ghost.enabled", accountId: 1)`, затем
    `set(.bool(false), …)`; `defaults.object(forKey: "mokoGram.s.1.ghost.enabled") == nil` и
    `isChanged("ghost.enabled", accountId: 1) == false`.
  - `testAccountScopeIsolation`: `set(.bool(true), for: "ghost.enabled", accountId: 1)` даёт
    `bool(…, accountId: 2) == false`. Запись `.device` (тестовая, зарегистрированная в тесте),
    заданная через `accountId: 1`, читается через `accountId: 2`.
  - `testResetPageKeepsOthers`: после изменений `ghost.enabled` и `commands.enabled`
    `reset(page: .privacy, accountId: 1)` сбрасывает первый и оставляет второй.
  - `testDidChangePosted`: `set` шлёт `didChange` с `userInfo["key"] == "ghost.enabled"`.
  - `testIntClampsAndChoiceRange`: для зарегистрированной `int(min: 1, max: 10)` `set(.int(50))`
    сохраняет 10.
- [ ] **Step 2: Запуск.** Хост-тест из Global Constraints. Ожидается FAIL (`no such module` или
  неразрешённые символы).
- [ ] **Step 3: Реализация** указанных типов. Значения хранятся как `Bool`, `Int` или `String`
  в `UserDefaults`; тип записи определяет чтение.
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko): settings registry and app-group storage`.

### Task 3: Экспорт и импорт `.mokaset`

**Files:**
- Create: `submodules/Moko/MokoCore/Sources/MokoSettingsFile.swift`
- Create: `submodules/Moko/MokoCore/Tests/Fixtures/desktop.mokaset` (сделать на Desktop: включить «Призрак» и `commands.enabled`, добавить ключ `lag.level` = 2, экспортировать)
- Test: `submodules/Moko/MokoCore/Tests/MokoSettingsFileTests.swift` (фикстура подключается через `data` в `swift_test`)

**Interfaces:**
- Consumes: `MokoSettings` (Task 2).
- Produces:
  ```swift
  public struct MokoImportSummary: Equatable { public var changed: Int; public var unknown: Int; public var invalid: Int }
  public enum MokoSettingsFileError: Error, Equatable { case notJson, notMokaset, newerVersion, noValues }
  public enum MokoSettingsFile {
      public static func export(accountId: Int64, appVersion: String) -> Data
      public static func preview(_ data: Data, accountId: Int64) -> Result<MokoImportSummary, MokoSettingsFileError>
      public static func apply(_ data: Data, accountId: Int64) -> Result<MokoImportSummary, MokoSettingsFileError>
  }
  ```
- `export` пишет значения `.account` текущего аккаунта и `.device` одним плоским словарём
  `values`, как на Desktop. Неизвестные ключи, сохранённые прошлым импортом, тоже экспортируются.
- Неизвестные ключи `apply` складывает в `mokoGram.s.unknown.<key>` (JSON-строкой), чтобы
  плагин, зарегистрировавший запись позже, увидел своё значение.

- [ ] **Step 1: Тесты.**
  - `testRoundTrip`: изменить `ghost.enabled`, `ghost.read = false`, `commands.enabled`; `export`;
    `resetAll`; `apply` возвращает `changed == 3`, значения вернулись.
  - `testExportOnlyDifferences`: после `resetAll` у `export` `values` пустой (`{}`).
  - `testImportDesktopDefaultsKeepsGhostOff`: файл `{"format":"mokaset","version":1,"values":{"ghost.read":true}}`
    оставляет `bool("ghost.enabled") == false` и даёт `changed == 0` (`ghost.read = true` и так
    значение по умолчанию). Что эффективное скрытие при этом выключено, проверяет
    `MokoPrivacySettingsTests` в Task 4.
  - `testPreviewCountsUnknownAndInvalid`: значения `{"ghost.enabled":true,"lag.level":2,"commands.enabled":"yes"}`
    дают `preview == MokoImportSummary(changed: 1, unknown: 1, invalid: 1)`; `preview` ничего не меняет.
  - `testRejectsNewerVersion`: `version: 2` даёт `.newerVersion`; `{"format":"x"}` даёт `.notMokaset`.
  - `testDesktopFixture`: `apply(desktop.mokaset)` даёт `bool("ghost.enabled") == true`,
    `unknown >= 1` (`lag.level`).
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Реализация.** `JSONSerialization`; число из JSON для `.bool` считается `invalid`.
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko): .mokaset export and import compatible with Desktop`.

### Task 4: Перевести существующие `Moko*` на реестр и группу приложения

**Files:**
- Modify: `submodules/TelegramCore/BUILD` (dep `//submodules/Moko/MokoCore`)
- Modify: `submodules/TelegramCore/Sources/State/MokoPrivacySettings.swift`, `MokoGhostSchedule.swift`, `MokoQuickCommands.swift`, `MokoSnippets.swift`, `MokoLocalPeerNotes.swift`
- Create: `submodules/Moko/MokoCore/Sources/MokoLegacyMigration.swift`
- Modify: `submodules/TelegramUI/Sources/AppDelegate.swift` (около строки 561, где вычисляется `appGroupName`)
- Modify: `Telegram/NotificationService/Sources/NotificationService.swift` (около строки 791)
- Test: `submodules/Moko/MokoCore/Tests/MokoLegacyMigrationTests.swift`; обновить `submodules/TelegramCore/Tests/Moko*Tests.swift`

**Interfaces:**
- Consumes: `MokoStorage`, `MokoSettings` (Task 2).
- Produces:
  ```swift
  public enum MokoLegacyMigration {
      // Один раз (флаг "mokoGram.migrated.v1" в группе): переносит все ключи "mokoGram.*" из legacy в MokoStorage.defaults,
      // переводит флаги «Призрака» и команд в ключи реестра, удаляет перенесённое из legacy.
      public static func run(legacy: UserDefaults)
  }
  ```
- Отображение старых ключей (`<a>` — id аккаунта) на ключи реестра:
  - `mokoGram.hideTyping.<a>` → `ghost.typing`
  - `mokoGram.hideStoryViews.<a>` → `ghost.stories`
  - `mokoGram.suppressOnlineUpdates.<a>` → `ghost.online`
  - `mokoGram.suppressAutomaticRead.<a>` → `ghost.read`

  У каждого аккаунта, где хоть один из этих флагов был true, ставится `ghost.enabled = true`, а
  невключённые подфлаги явно ставятся в `false`.

  Расписание: `mokoGram.ghostSchedule.{enabled,from,to,read,online,typing,stories}.<a>` →
  `ghost.schedule`, `ghost.schedule_from`, `ghost.schedule_to`, `ghost.sched_read`,
  `ghost.sched_online`, `ghost.sched_typing`, `ghost.sched_stories`.

  `mokoGram.quickCommands.<a>` → `commands.enabled`. Алиасы, сниппеты, заметки и исключения
  чтения остаются отдельными ключами данных, но переезжают в группу приложения.
- Публичные сигнатуры `MokoPrivacySettings`, `MokoGhostSchedule`, `MokoQuickCommands` не меняются,
  кроме умолчания параметра `defaults:` (теперь `MokoStorage.defaults`).
  `storedFlags(accountId:)` = `ghost.enabled && ghost.<x>`; сеттеры пишут подфлаг и включают
  `ghost.enabled`, когда подфлаг становится true.

- [ ] **Step 1: Тесты миграции.**
  - `testMigratesLegacyTypingFlag`: legacy `mokoGram.hideTyping.7 = true`, остальные отсутствуют;
    после `run` `bool("ghost.enabled", 7) == true`, `bool("ghost.typing", 7) == true`,
    `bool("ghost.read", 7) == false`, `bool("ghost.online", 7) == false`; в legacy ключа больше нет.
  - `testMigratesSchedule`: legacy `from = "22:30"`, `enabled = true`;
    `string("ghost.schedule_from", 7) == "22:30"`, `bool("ghost.schedule", 7) == true`.
  - `testMovesDataKeys`: legacy `mokoGram.snippets.7 = ["hi": "Hello"]` переезжает в
    `MokoStorage.defaults` без изменений.
  - `testRunsOnce`: второй `run` после ручного изменения legacy ничего не переносит.
- [ ] **Step 2: Запуск** хост-тестов. Ожидается FAIL.
- [ ] **Step 3: Реализовать `MokoLegacyMigration.run`** и перевести `Moko*` на реестр.
- [ ] **Step 4: Запуск** хост-тестов (PASS), затем `test-local.sh //submodules/TelegramCore:TelegramCoreTests`.
  В обновлённых `MokoPrivacySettingsTests` и `MokoGhostScheduleTests` ожидается PASS.
- [ ] **Step 5: Подключить при запуске.** В `AppDelegate` до создания аккаунтов:
  `MokoStorage.configure(appGroupName: appGroupName)`, затем
  `MokoLegacyMigration.run(legacy: .standard)`. В `NotificationService` только `configure`, без
  миграции: миграцию выполняет приложение.
- [ ] **Step 6: Полная сборка** (PASS) и коммит
  `refactor(moko): move existing settings to the registry and app group`.

### Task 5: Таблица строк mokaGram

**Files:**
- Create: `submodules/Moko/MokoCore/Strings/desktop.inc` (копия `Telegram/SourceFiles/mokagram/lang/mokagram_lang_table.inc` из Desktop `bb203b658d`)
- Create: `submodules/Moko/MokoCore/Strings/ios.inc` (тот же формат `{ "рус", "eng" },`; сюда переезжают все пары `isRussian ? … : …` из текущих iOS-файлов)
- Create: `build-system/mokagram/gen-moko-strings.py`
- Create: `submodules/Moko/MokoCore/Sources/MokoStrings.swift`, `submodules/Moko/MokoCore/Sources/MokoStringsTable.generated.swift`
- Test: `submodules/Moko/MokoCore/Tests/MokoStringsTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum MokoStrings {
      public static func tr(_ russian: String, languageCode: String) -> String
      public static func tr(_ russian: String, languageCode: String, _ args: String...) -> String  // %1, %2 как на Desktop
  }
  ```
- `gen-moko-strings.py` читает оба `.inc` (при повторе ключа побеждает `ios.inc`) и пишет
  `MokoStringsTable.generated.swift` со словарём `let mokoEnglishTable: [String: String]`.
  Сгенерированный файл коммитится; заголовок файла говорит, чем его пересоздать.

- [ ] **Step 1: Тесты.**
  - `testRussianFamilyKeepsRussian`: `tr("(пусто)", languageCode: "uk") == "(пусто)"`.
  - `testEnglishForOthers`: `tr("(пусто)", languageCode: "de") == "(empty)"`.
  - `testMissingFallsBackToRussian`: `tr("нет такого", languageCode: "en") == "нет такого"`.
  - `testArgs`: `tr("  (чатов: %1)", languageCode: "en", "3") == "  (chats: 3)"`.
  - `testBaseLanguageCode`: `tr("(пусто)", languageCode: "ru-RU") == "(пусто)"` (сравнивается часть до `-`).
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Генератор, затем `MokoStrings`.** `python3 build-system/mokagram/gen-moko-strings.py`.
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko): Desktop string table with English fallback`.

### Task 6: Экран «mokaGram» в Настройках

**Files:**
- Create: `submodules/Moko/MokoSettingsUI/BUILD`, `submodules/Moko/MokoSettingsUI/Sources/MokoSettingsController.swift`, `MokoSettingsPageController.swift`, `PresentationStrings+Moko.swift`
- Modify: `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoSettingsItems.swift` (секции `.mokoPrivacy` и `.mokoSnippets` заменяются одной секцией `.moko` с одной строкой)
- Modify: `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/BUILD` (dep на `MokoSettingsUI`)

**Interfaces:**
- Consumes: `MokoSettings`, `MokoSettingsFile`, `MokoStrings`.
- Produces:
  ```swift
  public func mokoSettingsController(context: AccountContext) -> ViewController
  public func mokoSettingsPageController(context: AccountContext, page: MokoSettingPage) -> ViewController
  extension PresentationStrings { public func moko(_ russian: String, _ args: String...) -> String }  // MokoStrings.tr с baseLanguageCode
  // Для строк, которые функции добавляют сами (Сниппеты, Алиасы, позже Музыка):
  public struct MokoSettingsCustomRow { public let page: MokoSettingPage; public let section: String; public let title: String; public let open: (AccountContext) -> ViewController? }
  public enum MokoSettingsCustomRows { public static func register(_ row: MokoSettingsCustomRow) }
  ```
- Корень: страницы в порядке `MokoSettingPage.allCases` (только непустые), их названия:
  Приватность, Безопасность, Удалёнки, Чаты, Музыка, Инструменты, Система. Затем группа
  «Перенос»: «Экспорт настроек» (лист «Поделиться» с файлом
  `mokagram-<yyyy-MM-dd>.mokaset`) и «Импорт настроек» (выбор файла → окно со сводкой
  `changed`/`unknown`/`invalid` → «Применить»). Затем «Сбросить всё» с подтверждением. Затем
  авторство: «Основано на mokaGram, автор @ecronx» (ссылка `https://t.me/ecronx`) и
  «Исходный код mokaGram» (`https://github.com/ecronxy/mokagram`).
- Страница: записи сгруппированы по `section`.
  - `.bool` → переключатель;
  - `.int` и `.choice` → строка-раскрытие со списком или ползунком;
  - `.string` и `.color` → строка с полем ввода (`#RRGGBB` с проверкой);
  - `.action` → строка-кнопка.

  Описание показывается сноской под строкой. Строка неактивна, если `dependsOn` false. Если
  значение изменено, в конце строки точка-метка, долгое нажатие сбрасывает. Строки `hidden` не
  показываются. После изменения `requiresRestart` появляется подсказка «Нужен перезапуск».
- Расписание «Призрака»: строки `ghost.schedule`, `ghost.schedule_from`, `ghost.schedule_to` и
  четыре `ghost.sched_*` показываются на странице «Приватность» отдельной группой «По
  расписанию».
- Образец экрана: `submodules/SettingsUI/Sources/ArchiveSettingsController.swift` (ItemListController,
  entries/state, `ItemListSwitchItem`, `ItemListTextItem`).

- [ ] **Step 1: Сделать экран** и строку «mokaGram» (значок `PresentationResourcesSettings.settings`) в
  Настройках над «Поддержкой». Сниппеты и алиасы переходят в
  `MokoSettingsCustomRows` на страницу «Инструменты» (логика `MokoSnippetSettings` не меняется).
- [ ] **Step 2: Полная сборка.** Ожидается PASS.
- [ ] **Step 3: Проверка в симуляторе через XcodeBuildMCP** (обновить приложение по рецепту из
  `CLAUDE.md`):
  1. Настройки → mokaGram → Приватность: «Призрак» выключен, подфлаги неактивны.
  2. Включить «Призрак» и выключить «Скрывать «печатает»». Метка «изменено» появилась.
  3. Перезапустить приложение: значения сохранились.
  4. Экспорт: открылся лист «Поделиться» с файлом `.mokaset`.
  5. Импортировать фикстуру Desktop из Task 3: сводка показывает `changed`/`unknown`.
  6. Переключиться на второй аккаунт: «Призрак» выключен.

  Сохранить скриншоты.
- [ ] **Step 4: Проверка на устройстве** (после Task 7): включить режим «Призрака» в приложении,
  затем проверить, что расширение уведомлений читает то же значение. Временный лог
  `NSLog("moko ghost.enabled=%d")` в `NotificationService` перед проверкой ставится и после
  удаляется.
- [ ] **Step 5: Коммит** `feat(moko): mokaGram settings screen driven by the registry`.

### Task 7: Подписанная сборка в CI и проверка пушей

**Files:**
- Modify: `build-system/mokagram/prepare.py` (режим настоящей подписи)
- Modify: `.github/workflows/build.yml`
- Modify: `README.md` (раздел «Подпись»)
- Modify: `openspec/changes/port-mokagram-desktop/design.md` (раздел 7: результат проверки пушей)

**Interfaces:**
- `prepare.py` переходит в режим настоящей подписи, если задан `MOKAGRAM_SIGNING_P12_BASE64`.
  Ему нужны ещё `MOKAGRAM_SIGNING_P12_PASSWORD`, `MOKAGRAM_PROFILES_ZIP_BASE64`,
  `MOKAGRAM_TEAM_ID`, `MOKAGRAM_BUNDLE_ID`. Сертификат кладётся в
  `build-input/mokagram/signing/certs/Distribution.p12`. Профили распаковываются в `profiles/`
  под именами из словаря `suffixes` (`Telegram`, `Intents`, `NotificationContent`,
  `NotificationService`, `Share`, `Widget`, `BroadcastUpload`). Если какого-то профиля не
  хватает, сборка падает с его именем.
- Без этих переменных поведение прежнее: заглушка и неподписанный IPA.
- Workflow: шаг импорта связки ключей берёт `.p12` и пароль из секретов. Артефакт называется
  `Mokagram-adhoc.ipa`, если подпись настоящая, иначе как сейчас.

- [ ] **Step 1: Реализовать режим в `prepare.py`.** Проверка: запуск без переменных даёт тот же вывод
  `Prepared Mokagram configuration and placeholder signing material`. Запуск с поддельным zip без
  `Share.mobileprovision` падает с `missing provisioning profile: Share`.
- [ ] **Step 2: Workflow и README.** В README перечислено, что создать в Apple Developer:
  - App ID `<bundle>` и шесть расширений с суффиксами из `prepare.py`;
  - группа `group.<bundle>` у всех семи;
  - Push Notifications у приложения;
  - ad-hoc профили с UDID устройств;
  - пять секретов GitHub.
- [ ] **Step 3 (делает человек с доступом к аккаунту): создать идентификаторы и секреты**, запустить workflow.
  Ожидается артефакт `Mokagram-adhoc.ipa`, который ставится на зарегистрированный iPhone.
- [ ] **Step 4: Проверка пушей на устройстве.**
  1. Войти в аккаунт и свернуть приложение.
  2. Написать себе с другого устройства.
  3. Записать результат в раздел 7 `design.md`: пуш пришёл или нет. Если не пришёл, в README
     добавить строку «Уведомления приходят только при открытом приложении».
- [ ] **Step 5: Коммит** `ci(moko): ad-hoc signing with a paid developer account`.
