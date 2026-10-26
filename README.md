# Mokagram iOS

Отдельная iOS-основа Mokagram в [kapustaltd](https://github.com/kapustaltd/mokagram-ios).
Основана на официальном [Telegram iOS](https://github.com/TelegramMessenger/Telegram-iOS),
релиз `release-13.0.0`. История upstream сохранена. Функции Desktop Mokagram пока не перенесены.
Название приложения и интерфейс пока остаются upstream.

## Сборка IPA

Откройте **Actions → Build Mokagram IPA → Run workflow** на ветке `main`.
Сборка запускается вручную на `macos-26` с Xcode 26.6 и Bazel из `versions.json`.
Конфигурация — `debug_arm64`, для настоящего iPhone/iPad, не для симулятора.
После успешного запуска скачайте артефакт **Mokagram-unsigned-ipa**:
`Mokagram-unsigned.ipa` и его SHA-256. Срок хранения — 14 дней.
Первый запуск компилирует зависимости и может занять несколько часов.

По умолчанию используются тестовые API ID `17349` и API hash из Desktop Mokagram
(`docs/api_credentials.md`). Для своей пары добавьте **оба** repository Secrets:
`TELEGRAM_API_ID` и `TELEGRAM_API_HASH` с https://my.telegram.org/apps.
Тестовая пара имеет ограничения Telegram API и может давать ошибки входа.

Сборочный скрипт создаёт одноразовый самоподписанный сертификат и placeholder-профили.
Они нужны упаковщику, но **не позволяют установить IPA на устройство**.
Перед установкой переподпишите IPA своей Apple-учётной записью через инструмент sideload.
App Groups, расширения и push требуют совместимых provisioning profiles и entitlements;
работа этих возможностей после сторонней переподписи не проверена.
Настоящая distribution-подпись и публикация в App Store пока не настроены.

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
