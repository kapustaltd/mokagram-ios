# mokaGram iOS, фаза 1: музыка — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Перенести музыку mokaGram Desktop:
- поиск и воспроизведение SoundCloud с очередью;
- тексты песен с перемоткой по строке;
- лайки, история и подборка «Для вас»;
- поиск музыки по чатам;
- отправка трека в чат и в профиль.

**Architecture:** Вся логика без UI лежит в модуле `submodules/Moko/MokoMusic` (Foundation и
SwiftSignalKit): клиент SoundCloud, загрузчик, тексты, библиотека и рекомендации, очередь. Модуль
переносится с Desktop поведение в поведение и тестируется на хосте через подменный HTTP-транспорт.
Воспроизведение идёт через штатный `SharedMediaPlayer`. Скачанный трек становится локальным
`TelegramMediaFile`, плейлист сделан по образцу `InstantPageMediaPlaylist`. Полный плеер iOS
показывает очередь так же, как для rich-сообщений. Экраны лежат в `submodules/Moko/MokoMusicUI`.

**Tech Stack:** Swift 6.4, Bazel, SwiftSignalKit, URLSession, ItemListUI/Display, AccountContext (`SharedMediaPlaylist`), TelegramCore.

**Spec:** `openspec/changes/port-mokagram-desktop/design.md`, раздел 4.6. Поведение сверяется с
Desktop `bb203b658d`, файлы `Telegram/SourceFiles/mokagram/music/*.cpp` (ниже «Desktop
`<файл>:<строки>`»).

**Depends on:** фаза 0 (`MokoCore`: `MokoStorage`, `MokoSettings`, `MokoStrings`; `MokoSettingsUI`: `MokoSettingsCustomRows`).

## Global Constraints

- SoundCloud: `https://api-v2.soundcloud.com`. `client_id` берётся со `https://soundcloud.com/`, обновляется при 401/403 один раз за запрос. Размер страницы поиска 20.
- Тексты: LRCLIB `https://lrclib.net/api/search` с `User-Agent: mokaGram (https://github.com/ecronx/mokagram)`. Запасной NetEase `https://music.163.com/api/search/get?type=1&limit=8&s=…` и `…/api/song/lyric?lv=1&kv=1&tv=-1&id=…` с `Referer: https://music.163.com/`.
- Настройки (страница `music`, область `.device`): `player.autoplay_next` (true), `player.cover_colors` (true), `lyrics.enabled` (true), заголовки с Desktop `appearance/mokagram_appearance.cpp:187-212`. Только iOS: `music.cache_mb` (int 100…5000, по умолчанию 500, «Кэш музыки, МБ»).
- Лайки, история, кэш треков и `client_id` общие для всех аккаунтов. Библиотека: `MokoStorage.containerURL/mokagram_music/library.json`. Треки: `Library/Caches/mokagram_music/<id>.<ext>`.
- id локального файла трека: `MediaId(namespace: Namespaces.Media.LocalFile, id: Int64(bitPattern: 0x4D4F4B0000000000 &+ UInt64(trackId)!))`, как `DocumentIdForTrack` на Desktop.
- Все тексты интерфейса берутся через `presentationData.strings.moko("…")` с русским текстом Desktop.
- Хост-тест: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/Moko/MokoMusic:MokoMusicTests --test_output=errors`.
- Полная сборка и обновление симулятора, как в фазе 0. Сообщения коммитов заканчиваются строкой `Claude-Session: https://claude.ai/code/session_017fhth1mtnEWVANtNj4DtQp`.

## Review Focus

- `client_id` протух посреди сеанса. Ожидается одно обновление и повтор, затем понятная ошибка, а не бесконечный цикл (`testRefreshesClientIdOnceOn401`, Task 2).
- Лайкнутый трек открыли через неделю, ссылки на поток уже недействительны. Перед скачиванием трек всегда разрешается заново по id (`testDownloadResolvesStoredTrack`, Task 3).
- Следующий трек не скачался (нет сети, трек закрыт). Очередь пропускает его и идёт дальше, а не встаёт; если не скачался ни один, она останавливается (`testSkipsFailedTrack`, `testStopsWhenAllFail`, Task 5).
- HLS с относительными адресами сегментов и `EXT-X-MAP` (`testHlsResolvesRelativeAndInit`, Task 3).
- Очистка кэша по лимиту не удаляет играющий трек (`testPruneKeepsProtectedFile`, Task 3).

---

### Task 1: Модуль MokoMusic, модель трека и разбор ответа SoundCloud

**Files:**
- Create: `submodules/Moko/MokoMusic/BUILD` (`swift_library` `MokoMusic`, deps `//submodules/SSignalKit/SwiftSignalKit`, `//submodules/Moko/MokoCore`; `swift_test` `MokoMusicTests` с `data = glob(["Tests/Fixtures/**"])`)
- Create: `submodules/Moko/MokoMusic/Sources/MokoMusicTrack.swift`, `Sources/MokoHTTP.swift`
- Create: `submodules/Moko/MokoMusic/Tests/Fixtures/search_tracks.json` (ответ `GET /search/tracks?q=lofi&limit=20`, снятый один раз через `curl` с действующим `client_id`; поле `client_id` в фикстуре не хранить)
- Test: `submodules/Moko/MokoMusic/Tests/MokoMusicTrackTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct MokoMusicTrack: Codable, Hashable {
      public var id: String; public var title: String; public var artist: String
      public var artworkUrl: String; public var permalink: String
      public var transcodingUrl: String; public var authorization: String
      public var fileExtension: String          // "mp3" | "m4a"
      public var durationMs: Int; public var isHls: Bool
      public var artistId: String; public var genre: String; public var tags: [String]
      public var playbackCount: Int64; public var likesCount: Int64; public var createdAt: Int64
      public var largeArtworkUrl: String { get }   // "-large" → "-t500x500"
  }
  public enum MokoSoundCloudParser {
      public static func track(_ object: [String: Any]) -> MokoMusicTrack
      public static func collection(_ data: Data) -> (tracks: [MokoMusicTrack], hasNext: Bool)  // только треки с непустыми transcodingUrl и id
  }
  public struct MokoHTTPResponse { public let status: Int; public let data: Data; public let url: URL }
  public enum MokoMusicError: Error, Equatable {
      case noClientId, clientIdExpired, network(status: Int), unavailable, noStreamUrl, emptyPlaylist, segmentFailed, writeFailed
  }
  public protocol MokoHTTPTransport { func get(_ url: URL, headers: [String: String]) -> Signal<MokoHTTPResponse, MokoMusicError> }
  public final class MokoURLSessionTransport: MokoHTTPTransport { public init(timeout: TimeInterval = 20) }
  ```
- Правила разбора дословно с Desktop `mokagram_soundcloud.cpp:162-240`:
  - пропускать `snipped`;
  - приоритет вариантов: progressive mpeg (mp3), затем hls mp4 (m4a), затем hls mpeg без
    `mpegurl` (mp3);
  - пустой `artwork_url` заменяется на `user.avatar_url`;
  - `tag_list`: слова и фразы в кавычках, в нижнем регистре, не больше 12.

- [ ] **Step 1: Тесты.**
  - `testPrefersProgressiveMp3`: словарь с тремя транскодингами (progressive `audio/mpeg`,
    hls `audio/mp4; codecs="mp4a.40.2"`, hls `audio/mpeg`) даёт `fileExtension == "mp3"`,
    `isHls == false`, `transcodingUrl` progressive.
  - `testFallsBackToHlsAac`: без progressive получается `"m4a"`, `isHls == true`.
  - `testSkipsSnipped`: единственный транскодинг `snipped: true` даёт `transcodingUrl == ""`.
  - `testTags`: `tag_list = "lofi \"chill hop\" Beats"` даёт `["lofi", "chill hop", "beats"]`.
  - `testArtworkFallbackAndLarge`: без `artwork_url` берётся `user.avatar_url`;
    `…/x-large.jpg` даёт `largeArtworkUrl == …/x-t500x500.jpg`.
  - `testFixtureCollection`: `collection(search_tracks.json)` не пуст, у каждого трека непустые
    `id` и `transcodingUrl`, `hasNext == true`.
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Реализация.** `MokoURLSessionTransport` следует редиректам и не переводит 4xx в ошибку: ошибкой считается только сбой сети (`network(status: 0)`).
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko-music): SoundCloud track model and parser`.

### Task 2: Клиент SoundCloud

**Files:**
- Create: `submodules/Moko/MokoMusic/Sources/MokoSoundCloudClient.swift`
- Test: `submodules/Moko/MokoMusic/Tests/MokoSoundCloudClientTests.swift` (фейковый `MokoHTTPTransport`: словарь «URL без query → ответ», журнал запросов)

**Interfaces:**
- Consumes: `MokoHTTPTransport`, `MokoSoundCloudParser` (Task 1).
- Produces:
  ```swift
  public struct MokoSearchPage: Equatable { public var tracks: [MokoMusicTrack]; public var nextOffset: Int? }
  public final class MokoSoundCloudClient {
      public init(transport: MokoHTTPTransport, clientIdFile: URL)
      public func search(_ query: String, offset: Int) -> Signal<MokoSearchPage, MokoMusicError>  // limit 20; nextOffset = offset+20, если next_href не пуст
      public func searchLimited(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError>
      public func resolve(_ track: MokoMusicTrack) -> Signal<MokoMusicTrack, MokoMusicError>  // GET /tracks/<id>; пустой transcodingUrl → .unavailable
      public func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError>  // /tracks/<id>/related
      public func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], MokoMusicError>  // /users/<id>/tracks
      func apiGet(_ url: URL, query: [URLQueryItem]) -> Signal<Data, MokoMusicError>  // internal: используется загрузчиком (Task 3)
  }
  ```
- Поиск `client_id` дословно с Desktop `mokagram_soundcloud.cpp:61-120`:
  - на главной найти скрипты по `https://a-v2\.sndcdn\.com/assets/[^"']+\.js`;
  - перебирать их с конца;
  - искать `client_id:"([A-Za-z0-9]{32})"`;
  - найденное записать в `clientIdFile`.

  При 401/403 `client_id` ищется заново принудительно, и запрос повторяется один раз. Второй
  401/403 даёт `.clientIdExpired`. Код ≥ 400 даёт `.network(status:)`.

- [ ] **Step 1: Тесты.**
  - `testDiscoversClientIdFromLastScript`: главная ссылается на `a.js` и `b.js`, `client_id`
    есть только в `a.js`; `search` запрашивает сначала `b.js`, потом `a.js`, затем `/search/tracks`
    с `client_id=<32 знака>`; файл записан.
  - `testUsesCachedClientId`: `client_id` уже в файле, главная не запрашивается.
  - `testRefreshesClientIdOnceOn401`: первый `/search/tracks` отвечает 401, после обновления 200;
    результат успешный, главная запрошена один раз. Если оба ответа 401, итог `.clientIdExpired`
    и ровно два запроса поиска.
  - `testPagingOffsets`: при непустом `next_href` получается `nextOffset == 20` для `offset: 0`,
    при пустом `nil`.
  - `testResolveUnavailable`: `/tracks/1` без транскодингов даёт `.unavailable`.
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Реализация.**
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko-music): SoundCloud client with client_id discovery`.

### Task 3: Загрузчик треков и кэш

**Files:**
- Create: `submodules/Moko/MokoMusic/Sources/MokoTrackDownloader.swift`
- Test: `submodules/Moko/MokoMusic/Tests/MokoTrackDownloaderTests.swift` (временная папка как кэш)

**Interfaces:**
- Consumes: `MokoSoundCloudClient.resolve`, `apiGet` (Task 2).
- Produces:
  ```swift
  public final class MokoTrackDownloader {
      public init(client: MokoSoundCloudClient, transport: MokoHTTPTransport, cacheDirectory: URL, limitBytes: @escaping () -> Int64)
      public func cachedFile(for track: MokoMusicTrack) -> URL?
      public func download(_ track: MokoMusicTrack) -> Signal<URL, MokoMusicError>
      public func prune(protecting: Set<URL>)   // удаляет самые старые по дате изменения, пока размер > limitBytes()
      public func clear(protecting: Set<URL>)
      public static func hlsParts(playlist: String, base: URL) -> [URL]   // EXT-X-MAP URI первым, затем строки без '#', относительные к base
  }
  ```
- `download`:
  1. Если есть `<id>.<ext>`, сразу вернуть его.
  2. Иначе `resolve(track)`: ссылки живут недолго, так что разрешение нужно всегда.
  3. `apiGet(transcodingUrl, [track_authorization])` даёт JSON `url`; пустой означает `.noStreamUrl`.
  4. Progressive качается одним запросом. HLS: плейлист, затем сегменты по порядку, склейка.
  5. Запись в `.part`, переименование, потом `prune(protecting: [итог])`.

  Ошибки как на Desktop `mokagram_soundcloud.cpp:228-330`.

- [ ] **Step 1: Тесты.**
  - `testHlsResolvesRelativeAndInit`: плейлист `#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:10,\nseg1.m4s\n#EXTINF:10,\nhttps://cdn/x/seg2.m4s`
    с base `https://cdn/a/p.m3u8` даёт `[https://cdn/a/init.mp4, https://cdn/a/seg1.m4s, https://cdn/x/seg2.m4s]`.
  - `testDownloadConcatenatesHls`: три части с байтами `A`, `B`, `C` дают файл `ABC` с именем `<id>.m4a`.
  - `testDownloadResolvesStoredTrack`: у трека устаревший `transcodingUrl`; загрузчик берёт ссылку
    из ответа `/tracks/<id>` (в журнале запросов сначала `/tracks/<id>`).
  - `testReturnsCachedWithoutNetwork`: при существующем файле запросов ноль.
  - `testPruneKeepsProtectedFile`: три файла по 1 МБ, лимит 1 МБ; при защите самого старого
    остаётся он, а удаляются два остальных.
  - `testSegmentFailureLeavesNoFile`: второй сегмент отвечает 500, итог `.segmentFailed`, ни
    `.part`, ни итогового файла нет.
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Реализация.**
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko-music): track downloader with HLS and cache limit`.

### Task 4: Тексты песен

**Files:**
- Create: `submodules/Moko/MokoMusic/Sources/MokoLyrics.swift`
- Test: `submodules/Moko/MokoMusic/Tests/MokoLyricsTests.swift`

**Interfaces:**
- Consumes: `MokoHTTPTransport`.
- Produces:
  ```swift
  public struct MokoLyricLine: Equatable { public var timeMs: Int64; public var text: String }
  public struct MokoLyrics: Equatable { public var lines: [MokoLyricLine]; public var synced: Bool; public var found: Bool }
  public enum MokoLyricsParsing {
      public static func parseLrc(_ text: String) -> MokoLyrics
      public static func parsePlain(_ text: String) -> MokoLyrics
      public static func scaleTimes(_ lyrics: MokoLyrics, ratio: Double) -> MokoLyrics
      public static func cleanTitle(_ title: String, artist: String) -> String
      public static func withoutBrackets(_ text: String) -> String
      public static func pick(_ list: [[String: Any]], durationMs: Int64, matchingTitle: String?) -> MokoLyrics
  }
  public final class MokoLyricsService {
      public init(transport: MokoHTTPTransport)
      public func fetch(cacheKey: String, title: String, artist: String, durationMs: Int64) -> Signal<MokoLyrics, NoError>
  }
  ```
- Функции переносятся один в один с Desktop `mokagram_lyrics.cpp`:
  - `ParseLrc` 20-60, `ScaleTimes` 62-71 (порог 0.01), `ParsePlain`, `WithoutBrackets`;
  - `Pick` 82-150: очки 100/60/10, окно 12000 мс, 3000 мс для `matchingTitle`, `ratio` от 0.5 до 2;
  - `CleanTitle` 296-313;
  - порядок запросов `FetchLyrics` 314-378;
  - фильтр строк с авторами у NetEase 252-262.

  Кэшируется только найденное, в памяти, по `cacheKey`. Неудачу не запоминаем, потому что сеть
  могла моргнуть.

- [ ] **Step 1: Тесты.**
  - `testParseLrcMultipleStamps`: `[00:01.50][00:10.00]Hi\n[00:05]Yo` даёт времена `[1500, 5000, 10000]`, `synced == true`.
  - `testScaleTimes`: `ratio: 1.25` делает `1000` равным `1250`; `ratio: 1.005` ничего не меняет.
  - `testCleanTitle`: `cleanTitle("Artist - Song (Official Video).mp3", artist: "Artist") == "Song"`.
  - `testPickPrefersSyncedWithinWindow`: synced с длиной 200 с и plain с длиной 201 с при
    `durationMs: 205000` дают synced.
  - `testPickSpedUpScales`: synced с длиной 200 с при `durationMs: 160000` даёт `synced == true` и
    первое время, умноженное на 0.8.
  - `testFetchOrderAndNeteaseFallback`: фейковый транспорт возвращает пустые массивы LRCLIB;
    журнал запросов: `track_name+artist_name`, затем `q`, затем `track_name`, затем NetEase
    search и lyric. Строка `作词 : X` отфильтрована.
  - `testFailureNotCached`: первый `fetch` без результата, второй с тем же ключом снова ходит в сеть.
- [ ] **Step 2: Запуск.** Ожидается FAIL.
- [ ] **Step 3: Реализация.**
- [ ] **Step 4: Запуск.** Ожидается PASS.
- [ ] **Step 5: Коммит** `feat(moko-music): LRCLIB and NetEase lyrics`.

### Task 5: Очередь, лайки, история и «Для вас»

**Files:**
- Create: `submodules/Moko/MokoMusic/Sources/MokoMusicQueue.swift`, `Sources/MokoMusicLibrary.swift`, `Sources/MokoRecommender.swift`
- Test: `submodules/Moko/MokoMusic/Tests/MokoMusicQueueTests.swift`, `Tests/MokoMusicLibraryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum MokoQueueOrder { case regular, reversed, random }
  public enum MokoQueueLooping { case none, all, item }
  public struct MokoMusicQueue: Equatable {
      public private(set) var tracks: [MokoMusicTrack]; public private(set) var index: Int?
      public var order: MokoQueueOrder; public var looping: MokoQueueLooping
      public init(tracks: [MokoMusicTrack], startIndex: Int)
      public mutating func step(_ delta: Int, autoplay: Bool, random: () -> Int) -> Int?   // nil = конец
      public mutating func jump(to index: Int)
      public mutating func markFailed(_ index: Int)                 // такой трек пропускается в step
      public mutating func move(from: Int, to: Int); public mutating func remove(at: Int)
  }
  public final class MokoMusicLibrary {
      public init(file: URL, now: @escaping () -> Date = Date.init)
      public func isLiked(_ id: String) -> Bool
      public func setLiked(_ track: MokoMusicTrack, _ liked: Bool)
      public func likedTracks() -> [MokoMusicTrack]                  // новые сверху
      public func recordListen(_ track: MokoMusicTrack, listenedMs: Int, finished: Bool)
      public var hasTaste: Bool { get }
      public let changed: Signal<Void, NoError>
  }
  public protocol MokoRecommendationSource {
      func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
      func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
      func search(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], NoError>
  }
  public enum MokoRecommender {
      public static func buildForYou(library: MokoMusicLibrary, source: MokoRecommendationSource, count: Int, random: @escaping () -> Double) -> Signal<(tracks: [MokoMusicTrack], note: String), NoError>
  }
  ```
- `step` при `autoplay == false` и `delta == 1` из конца трека возвращает `nil`. Порядок и повтор
  как в `InstantPageMediaPlaylist.control` (`regular` означает +1). Неудавшиеся треки
  пропускаются; если неудачными помечены все, возвращается `nil`.
- Библиотека и рекомендатель переносятся с Desktop `mokagram_music_library.cpp` целиком:
  - `kHistoryLimit = 3000`, `kHalfLifeDays = 60`;
  - веса профиля 170-190;
  - очки кандидата 395-434 (1.6, 1.0, 0.7, 0.5, 0.25, 0.2, 0.15 и штрафы −2, −1.6, −1.5, −2);
  - разнообразие −0.55 за трек того же исполнителя, 442-475;
  - сбор кандидатов 500-540: related 25, исполнитель 12, жанр и теги по 20.

  Формат `library.json` тот же, что на Desktop. Файл Desktop, положенный в контейнер,
  читается без изменений.

- [ ] **Step 1: Тесты очереди.**
  - `testRegularNextAndEnd`: из 3 треков с индекса 2 при `step(1, autoplay: true)` и
    `looping: .none` получается `nil`; при `.all` получается 0.
  - `testAutoplayOffStops`: `step(1, autoplay: false)` с индекса 0 даёт `nil`.
  - `testSkipsFailedTrack`: `markFailed(1)`, затем `step(1)` с 0 даёт 2.
  - `testStopsWhenAllFail`: все помечены, `step` даёт `nil`.
  - `testItemLooping`: `.item` даёт тот же индекс.
- [ ] **Step 2: Тесты библиотеки.**
  - `testLikesPersistNewestFirst`: лайкнуть A, затем B; новый `MokoMusicLibrary` с тем же файлом даёт `[B, A]`.
  - `testHistoryCapped`: 3001 прослушивание оставляет в истории 3000.
  - `testSkipPenalizes`: прослушивание 5 с без `finished` даёт отрицательный вклад этого трека
    в профиль (через `buildForYou`: трек-кандидат, совпадающий с пропущенным, не попадает в
    первые 3 при `count: 3`).
  - `testDiversity`: 10 кандидатов одного исполнителя и 2 другого с равными очками при `count: 4`
    дают оба трека второго исполнителя.
  - `testNoTasteNote`: пустая библиотека даёт `tracks == []` и непустой `note` (русский текст
    Desktop «лайкни пару треков»).
- [ ] **Step 3: Запуск.** Ожидается FAIL.
- [ ] **Step 4: Реализация.**
- [ ] **Step 5: Запуск.** Ожидается PASS.
- [ ] **Step 6: Коммит** `feat(moko-music): queue, likes, history and For You`.

### Task 6: Воспроизведение через плеер приложения

**Files:**
- Create: `submodules/Moko/MokoMusicUI/BUILD`, `submodules/Moko/MokoMusicUI/Sources/MokoMusicPlaylist.swift`, `Sources/MokoMusicContext.swift`
- Create: `submodules/Moko/MokoCore/Sources/MokoArtworkRegistry.swift`
- Modify: `submodules/AccountContext/Sources/MediaManager.swift` (рядом с `InstantPagePlaylistLocation`: `MokoMusicPlaylistLocation`)
- Modify: `submodules/MusicAlbumArtResources/Sources/ExternalMusicAlbumArtResources.swift` (`fetchExternalMusicAlbumArtResource`) и его `BUILD`
- Modify: `submodules/TelegramUI/Components/MediaPlaybackHeaderPanelComponent/Sources/MediaPlaybackHeaderPanelComponent.swift` (`tapAction`, рядом с веткой `InstantPagePlaylistLocation`)
- Modify: `submodules/TelegramUI/Sources/OverlayAudioPlayerControllerNode.swift` (ветка источника около строки 116; выбор строки по образцу `playInstantPageTrack` около строки 642)
- Modify: `submodules/Moko/MokoCore/Sources/MokoBuiltinSettings.swift` (ключи музыки из Global Constraints)

**Interfaces:**
- Consumes: `MokoMusicQueue`, `MokoTrackDownloader`, `MokoMusicLibrary` (Tasks 3, 5).
- Produces:
  ```swift
  public enum MokoArtworkRegistry {                       // MokoCore
      public static func register(fileId: Int64, url: URL)
      public static func url(fileId: Int64) -> URL?
  }
  public struct MokoMusicPlaylistLocation: SharedMediaPlaylistLocation {   // AccountContext
      public let queueId: Int64
      public let tracks: [(index: Int, file: TelegramMediaFile)]
      public let jump: (Int) -> Void
  }
  public final class MokoMusicContext {                   // MokoMusicUI, один на процесс
      public static let shared: MokoMusicContext
      public let client: MokoSoundCloudClient; public let downloader: MokoTrackDownloader
      public let library: MokoMusicLibrary; public let lyrics: MokoLyricsService
      public func play(_ tracks: [MokoMusicTrack], startIndex: Int, context: AccountContext)
      public var currentQueue: Signal<MokoMusicQueue?, NoError> { get }
      public func localFile(for track: MokoMusicTrack, path: String) -> TelegramMediaFile
  }
  public final class MokoMusicPlaylist: SharedMediaPlaylist { init(queue: MokoMusicQueue, context: MokoMusicContext) }
  ```
- `localFile`:
  - ресурс `LocalFileReferenceMediaResource(localFilePath: path, randomId: <fileId>)`;
  - mime `audio/mpeg` или `audio/mp4`;
  - атрибут `.Audio(isVoice: false, duration: durationMs/1000, title:, performer: artist, waveform: nil)`;
  - `fileId` по правилу из Global Constraints;
  - регистрирует `largeArtworkUrl` в `MokoArtworkRegistry`.
- `fetchExternalMusicAlbumArtResource`: если `resource.file?.media.fileId.id` есть в реестре,
  обложка грузится по этому URL через URLSession одним `.dataPart(…, complete: true)`. Иначе путь
  прежний.
- `MokoMusicPlaylist`:
  - пока текущий трек качается, состояние `loading: true` с `item == nil`;
  - после загрузки item с `.telegramFile(reference: .standalone(media: file), isCopyProtected: false, isViewOnce: false)`
    и `displayData .music(title, performer, albumArt, long: false, caption: nil)`;
  - при старте трека качается следующий (предзагрузка);
  - ошибка загрузки вызывает `markFailed`, `step` и тост
    `presentationData.strings.moko("Трек недоступен, переключаю дальше")`;
  - `control(.next/.previous)` идёт через `queue.step` с `autoplay` из `player.autoplay_next`;
  - `onItemPlaybackStarted` пишет `recordListen` прошлого трека (прослушанные мс берутся из
    статуса плеера `mediaManager.musicMediaPlayerState`);
  - `location` отдаёт `MokoMusicPlaylistLocation`.
- Нажатие на мини-плеер при `MokoMusicPlaylistLocation` открывает
  `makeOverlayAudioPlayerController(… chatLocation: .peer(id: context.account.peerId), initialMessageId: <Local id = index>, playlistLocation:)`.
  Узел плеера строит очередь из синтезированных строк, как для rich-сообщений
  (`namespace: Namespaces.Message.Local`, `id = index`). Нажатие на строку вызывает `location.jump(index)`.

- [ ] **Step 1: Реализация и полная сборка.** Ожидается PASS.
- [ ] **Step 2: Проверка в симуляторе через XcodeBuildMCP.** Временная отладочная строка в
  Debug Settings «Moko: play test query» вызывает `play` с первыми тремя результатами поиска
  `lofi`. Проверить:
  1. мини-плеер показывает название и исполнителя;
  2. обложка SoundCloud видна в мини-плеере и полном плеере;
  3. «вперёд» и «назад» работают;
  4. в полном плеере очередь из 3 строк, нажатие на третью переключает;
  5. повтор и перемешивание из полного плеера меняют порядок;
  6. при выключенной сети следующий трек пропускается с тостом;
  7. на экране блокировки (`simctl`) показываются название и обложка.

  Скриншоты сохранить. Отладочную строку убрать перед коммитом.
- [ ] **Step 3: Коммит** `feat(moko-music): play SoundCloud queues through the app player`.

### Task 7: Экран «Музыка»

**Files:**
- Create: `submodules/Moko/MokoMusicUI/Sources/MokoMusicController.swift`, `Sources/MokoTrackItem.swift`, `Sources/MokoTrackActions.swift`
- Modify: `submodules/Moko/MokoMusicUI/Sources/MokoMusicContext.swift` (регистрация `MokoSettingsCustomRow` «Музыка» на странице `music`, строка-действие «Очистить кэш музыки»)

**Interfaces:**
- Consumes: `MokoMusicContext` (Task 6), `MokoRecommender` (Task 5), `TelegramEngine.Messages.searchMessages` с
  `.general(scope: .everywhere, groupId: nil, tags: .music, minDate: nil, maxDate: nil, folderId: nil, communityId: nil)`.
- Produces: `public func mokoMusicController(context: AccountContext, initialQuery: String?) -> ViewController`,
  `MokoTrackActions.present(track:, context:, from: ViewController)` (меню действий, используется в Task 8).
- Вкладки (сегменты в шапке): «Поиск», «Для вас», «Лайки», «В чатах».
  - Поиск: поле запроса, страницы по 20, подгрузка у нижнего края. Последний запрос
    запоминается, и при новом открытии поиск повторяется.
  - «Для вас»: `buildForYou(count: 30)`, кнопка «Обновить», пояснение `note`.
  - «Лайки»: `likedTracks()`.
  - «В чатах»: найденные сообщения с музыкой. Воспроизведение обычным плейлистом сообщений, как
    в поиске по музыке в списке чатов (`ChatListSearchListPaneNode`, `.custom`-location).
- Строка трека: обложка 44 pt со скруглением, название, исполнитель, длительность, сердце.
  Нажатие играет список вкладки с этого трека.
- Долгое нажатие открывает меню действий:
  - «Слушать»;
  - «Нравится» / «Убрать из понравившихся»;
  - «Отправить в чат» и «Добавить в профиль» (Task 8);
  - «Сохранить в Файлы» (download, затем лист «Поделиться»);
  - «Копировать ссылку» (`permalink`).
- Над вкладками полоса «Сейчас играет»: обложка, название, кнопка «Текст» (Task 9). При
  `player.cover_colors` фон полосы — средний цвет обложки с прозрачностью 0.25.
- Ошибки SoundCloud показываются строкой в списке с кнопкой «Повторить». Тексты:
  «не удалось получить client_id SoundCloud», «client_id SoundCloud устарел»,
  «сеть: %1 (код %2)» (с Desktop).

- [ ] **Step 1: Реализация и полная сборка.** Ожидается PASS.
- [ ] **Step 2: Проверка в симуляторе.** Настройки → mokaGram → Музыка → «Музыка». Проверить:
  1. поиск `lofi`, затем прокрутка до второй страницы;
  2. воспроизведение со 2-го трека;
  3. лайк, затем «Лайки» показывает трек и после перезапуска;
  4. «Для вас» после двух лайков не пуст;
  5. «В чатах» находит аудио из своего чата;
  6. в «Копировать ссылку» в буфере `https://soundcloud.com/…`;
  7. «Очистить кэш музыки» освобождает место.

  Скриншоты.
- [ ] **Step 3: Коммит** `feat(moko-music): music screen with search, For You, likes and chats`.

### Task 8: Отправка трека в чат и в профиль

**Files:**
- Modify: `submodules/Moko/MokoMusicUI/Sources/MokoTrackActions.swift`

**Interfaces:**
- Consumes: `MokoTrackDownloader.download`, `MokoMusicContext.localFile`, `context.sharedContext.makePeerSelectionController`, `TelegramEngine.Peers.addSavedMusic(file:afterFile:)`.
- Отправляемый файл получает:
  - те же атрибуты `.Audio`, что в Task 6;
  - имя файла `<artist> - <title>.<ext>`;
  - миниатюру из `largeArtworkUrl`: JPEG 320×320, качество 0.8, в `previewRepresentations`,
    чтобы обложка была у получателя.
- «Отправить в чат»: выбор чата, затем обычная отправка аудиофайла и тост «Отправлено».
- «Добавить в профиль»:
  1. отправка в «Избранное» (`context.account.peerId`);
  2. ожидание, пока у сообщения появится настоящий id;
  3. `addSavedMusic(file: .message(message: MessageReference(message), media: file))`;
  4. тост «Добавлено в профиль».

  При ошибке `addSavedMusic` тост с причиной, а сообщение в «Избранном» остаётся.

- [ ] **Step 1: Реализация и полная сборка.** Ожидается PASS.
- [ ] **Step 2: Проверка.**
  1. Трек отправлен в чат и у получателя играет с обложкой и названием.
  2. «Добавить в профиль»: трек появился в музыке профиля.
- [ ] **Step 3: Коммит** `feat(moko-music): send tracks to chats and to the profile`.

### Task 9: Тексты песен в плеере

**Files:**
- Create: `submodules/Moko/MokoMusicUI/Sources/MokoLyricsController.swift`
- Modify: `submodules/TelegramUI/Sources/OverlayPlayerControlsNode.swift` (кнопка «Текст» при `lyrics.enabled`, место рядом с кнопками порядка и повтора выбирает исполнитель)

**Interfaces:**
- Consumes: `MokoLyricsService.fetch` (Task 4). Название, исполнитель и длительность берутся из
  `displayData`/`.Audio` текущего трека, так что работает и для аудио из чатов (как на Desktop).
  Позиция из `mediaManager.musicMediaPlayerState`.
- Produces: `public func mokoLyricsController(context: AccountContext) -> ViewController`.
- Поведение (Desktop `14bc7da059`, `d57848c6b0`):
  - синхронный текст: текущая строка выделена и плавно держится по центру;
  - нажатие на строку делает `playlistControl(.seek(timeMs/1000), type: .music)`;
  - ручная прокрутка отключает автопрокрутку на 3 с;
  - обычный текст показывается прокручиваемым без выделения;
  - нет текста: «Текст не найден»; идёт загрузка: «Ищу текст…»;
  - смена трека перезагружает текст;
  - при «Уменьшении движения» без анимации масштаба.

- [ ] **Step 1: Реализация и полная сборка.** Ожидается PASS.
- [ ] **Step 2: Проверка в симуляторе.**
  1. Известный трек с синхронным текстом: строка следует за временем.
  2. Нажатие на 5-ю строку перематывает.
  3. После прокрутки пальцем автопрокрутка возвращается через 3 с.
  4. Аудио из чата без исполнителя: «Текст не найден» без падения.
- [ ] **Step 3: Коммит** `feat(moko-music): synced lyrics with tap-to-seek`.
