# Mokagram iOS

Отдельная iOS-основа Mokagram в [kapustaltd](https://github.com/kapustaltd/mokagram-ios).
Основана на официальном [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS),
релиз `release-13.0.0`. История upstream сохранена. Перенос функций Desktop Mokagram выполняется постепенно.
Название и значок адаптированы для iOS; остальной интерфейс пока остаётся upstream.

Айдентика основана на [mokaGram](https://github.com/ecronxy/mokagram), автор [@ecronx](https://t.me/ecronx). Уведомление об авторстве и условиях использования: [MOKAGRAM_NOTICE.md](MOKAGRAM_NOTICE.md).

В профиле собеседника можно добавить локальный тег и заметку. Они разделены по учётным записям, хранятся на устройстве и не синхронизируются с Desktop или Telegram. В настройках можно отключить отправку индикаторов действий в чате, просмотров историй и обновлений статуса «в сети» с этого устройства; в меню сообщения доступна основная информация о нём. Эти функции ещё требуют проверки на устройстве. План переноса остальных функций Desktop находится в [OpenSpec](openspec/changes/port-mokagram-desktop/tasks.md).

Настройка «Не читать при открытии чата» блокирует автоматическую отметку в чате и обсуждениях; в профиле чата можно добавить исключение. Ручные действия, уведомления, просмотр медиа и другие устройства могут отправить прочтение. Поведение ещё требует сетевой проверки.

В настройках также можно создавать текстовые сниппеты для обычных сообщений: `;имя` заменяется на сохранённый текст. Форматированные сниппеты и структурированные сообщения пока не поддерживаются; данные не синхронизируются с Desktop.

Для аккаунта можно включить команды `.calc`, `.id`, `.snip`, `.tag`, `.note`, `.archive`, `.unarchive`, `.mute`, `.unmute` и `.save` и назначить им алиасы. Эти команды не отправляются как сообщения; `.tag` и `.note` работают в обычных личных чатах, `.mute` меняет уведомления чата без ограничения участников, `.save` пересылает разрешённое сообщение в «Избранное». Архив и уведомления синхронизируются с Telegram. Отключённые и пока не реализованные команды обрабатываются как обычный текст.

## Сборка IPA

Откройте **Actions → Build Mokagram IPA → Run workflow** на ветке `main`.
Сборка запускается вручную на `macos-26` с Xcode 26.6 и Bazel из `versions.json`.
Конфигурация — `release_arm64` (не debug), для настоящего iPhone/iPad, не для симулятора.
После успешного запуска скачайте артефакт **Mokagram-adhoc-ipa** (с секретами подписи) или
**Mokagram-unsigned-ipa** (без них): IPA и его SHA-256. Срок хранения — 14 дней.
Первый запуск компилирует зависимости и может занять несколько часов.

По умолчанию используются тестовые API ID `17349` и API hash из Desktop Mokagram
(`docs/api_credentials.md`). Для своей пары добавьте **оба** repository Secrets:
`TELEGRAM_API_ID` и `TELEGRAM_API_HASH` с https://my.telegram.org/apps.
Тестовая пара имеет ограничения Telegram API и может давать ошибки входа.

Без секретов подписи сборочный скрипт создаёт одноразовый самоподписанный сертификат и
placeholder-профили. Такой IPA (**Mokagram-unsigned-ipa**) **не устанавливается на устройство**,
пока его не переподписать своей Apple-учётной записью.

## Подпись своим аккаунтом разработчика (ad-hoc)

С платным аккаунтом Apple Developer CI сразу выпускает подписанный IPA
(**Mokagram-adhoc-ipa**), который ставится на зарегистрированные iPhone (до 100 устройств в год).
App Store и внешний TestFlight не используются.

1. В Certificates, Identifiers & Profiles создайте App ID `<bundle>` и шесть App ID расширений:
   `<bundle>.SiriIntents`, `<bundle>.NotificationContent`, `<bundle>.NotificationService`,
   `<bundle>.Share`, `<bundle>.Widget`, `<bundle>.BroadcastUpload`.
2. Создайте App Group `group.<bundle>` и включите её у всех семи App ID.
   У основного App ID включите Push Notifications.
3. Зарегистрируйте UDID устройств и создайте сертификат Apple Distribution.
4. Создайте семь ad-hoc профилей и назовите файлы `Telegram.mobileprovision`,
   `Intents.mobileprovision`, `NotificationContent.mobileprovision`,
   `NotificationService.mobileprovision`, `Share.mobileprovision`, `Widget.mobileprovision`,
   `BroadcastUpload.mobileprovision`. Упакуйте их в один zip.
5. Добавьте repository Secrets:
   `MOKAGRAM_SIGNING_P12_BASE64` (`base64 -i cert.p12`), `MOKAGRAM_SIGNING_P12_PASSWORD`,
   `MOKAGRAM_PROFILES_ZIP_BASE64` (`base64 -i profiles.zip`), `MOKAGRAM_TEAM_ID`, `MOKAGRAM_BUNDLE_ID`.

Если какого-то профиля не хватает, сборка останавливается с его именем
(`missing provisioning profile: Share`). Проверка скрипта: `python3 -I build-system/mokagram/test_prepare.py`.

Доставка push-уведомлений для своего bundle id ещё не проверена (см. раздел 7 в
`openspec/changes/port-mokagram-desktop/design.md`).

## Локальная сборка на macOS

```sh
git clone --recursive https://github.com/kapustaltd/mokagram-ios.git
cd mokagram-ios
```

Используйте Xcode из `versions.json`. Подробности о сборке и настоящей подписи —
в [инструкции upstream](docs/upstream-build.md). Конфигурация приложения —
`build-system/mokagram/configuration.json`; генерируемые файлы находятся в игнорируемом
`build-input/mokagram/`. Desktop-репозиторий: https://github.com/kapustaltd/mokagram.

Исходные лицензии и уведомления Telegram и зависимостей сохранены в их файлах.
