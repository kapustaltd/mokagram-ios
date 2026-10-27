import Foundation
import XCTest
import MokoMusic

final class MokoLyricsTests: XCTestCase {
    func testParseLrcMultipleStamps() {
        let lyrics = MokoLyricsParsing.parseLrc("[00:01.50][00:10.00]Hi\n[00:05]Yo\nno stamp")
        XCTAssertEqual(lyrics.lines.map { $0.timeMs }, [1500, 5000, 10000])
        XCTAssertEqual(lyrics.lines.map { $0.text }, ["Hi", "Yo", "Hi"])
        XCTAssertTrue(lyrics.synced)
        XCTAssertTrue(lyrics.found)
    }

    func testScaleTimes() {
        let lyrics = MokoLyrics(lines: [MokoLyricLine(timeMs: 1000, text: "a")], synced: true, found: true)
        XCTAssertEqual(MokoLyricsParsing.scaleTimes(lyrics, ratio: 1.25).lines[0].timeMs, 1250)
        XCTAssertEqual(MokoLyricsParsing.scaleTimes(lyrics, ratio: 1.005).lines[0].timeMs, 1000)
    }

    func testCleanTitle() {
        XCTAssertEqual(MokoLyricsParsing.cleanTitle("Artist - Song (Official Video).mp3", artist: "Artist"), "Song")
        XCTAssertEqual(MokoLyricsParsing.cleanTitle("my_song  [Lyrics]", artist: ""), "my song")
        XCTAssertEqual(MokoLyricsParsing.withoutBrackets("Song (slowed + reverb)"), "Song")
        XCTAssertEqual(MokoLyricsParsing.withoutBrackets("(Intro)"), "(Intro)")
    }

    func testPickPrefersSyncedWithinWindow() {
        let list: [[String: Any]] = [
            ["plainLyrics": "plain", "duration": 201],
            ["syncedLyrics": "[00:01.00]synced", "duration": 200],
        ]
        let lyrics = MokoLyricsParsing.pick(list, durationMs: 205000, matchingTitle: nil)
        XCTAssertTrue(lyrics.synced)
        XCTAssertEqual(lyrics.lines.first?.text, "synced")
    }

    func testPickSpedUpScales() {
        let list: [[String: Any]] = [["syncedLyrics": "[00:10.00]line", "duration": 200]]
        let lyrics = MokoLyricsParsing.pick(list, durationMs: 160000, matchingTitle: nil)
        XCTAssertTrue(lyrics.synced)
        XCTAssertEqual(lyrics.lines.first?.timeMs, 8000)
    }

    func testPickMatchingTitleRejectsOtherSongs() {
        let list: [[String: Any]] = [["syncedLyrics": "[00:01.00]x", "duration": 200, "trackName": "Other", "artistName": "A"]]
        XCTAssertFalse(MokoLyricsParsing.pick(list, durationMs: 200000, matchingTitle: "Song").found)
    }

    func testFetchOrderAndNeteaseFallback() {
        let transport = MokoFakeTransport()
        transport.on("https://lrclib.net/api/search", "[]")
        transport.on("https://music.163.com/api/search/get", "{\"result\":{\"songs\":[{\"name\":\"Song\",\"duration\":180000,\"id\":77}]}}")
        transport.on("https://music.163.com/api/song/lyric", "{\"lrc\":{\"lyric\":\"[00:00.10]作词 : X\\n[00:02.00]Hello\"}}")
        let service = MokoLyricsService(transport: transport)
        let lyrics = mokoValue(service.fetch(cacheKey: "k", title: "Song", artist: "Artist", durationMs: 180000))!
        XCTAssertEqual(lyrics.lines.map { $0.text }, ["Hello"])
        XCTAssertEqual(transport.paths(), [
            "https://lrclib.net/api/search",
            "https://lrclib.net/api/search",
            "https://lrclib.net/api/search",
            "https://music.163.com/api/search/get",
            "https://music.163.com/api/song/lyric",
        ])
        let queries = transport.log.prefix(3).map { URLComponents(url: $0, resolvingAgainstBaseURL: false)!.queryItems!.map { "\($0.name)=\($0.value!)" } }
        XCTAssertEqual(queries[0], ["track_name=Song", "artist_name=Artist"])
        XCTAssertEqual(queries[1], ["q=Artist Song"])
        XCTAssertEqual(queries[2], ["track_name=Song"])
    }

    func testPlusIsPercentEncoded() {
        let transport = MokoFakeTransport()
        transport.on("https://lrclib.net/api/search", "[{\"syncedLyrics\":\"[00:01.00]x\",\"duration\":100}]")
        _ = mokoValue(MokoLyricsService(transport: transport).fetch(cacheKey: "p", title: "A+B", artist: "C", durationMs: 100000))
        XCTAssertTrue(transport.log[0].absoluteString.contains("track_name=A%2BB"), transport.log[0].absoluteString)
    }

    func testFailureNotCached() {
        let transport = MokoFakeTransport()
        transport.on("https://lrclib.net/api/search", "[]")
        transport.on("https://music.163.com/api/search/get", "{}")
        let service = MokoLyricsService(transport: transport)
        XCTAssertFalse(mokoValue(service.fetch(cacheKey: "same", title: "S", artist: "A", durationMs: 1000))!.found)
        let count = transport.log.count
        _ = mokoValue(service.fetch(cacheKey: "same", title: "S", artist: "A", durationMs: 1000))
        XCTAssertGreaterThan(transport.log.count, count)
    }

    func testFoundIsCached() {
        let transport = MokoFakeTransport()
        transport.on("https://lrclib.net/api/search", "[{\"syncedLyrics\":\"[00:01.00]x\",\"duration\":100}]")
        let service = MokoLyricsService(transport: transport)
        _ = mokoValue(service.fetch(cacheKey: "c", title: "S", artist: "A", durationMs: 100000))
        let count = transport.log.count
        XCTAssertTrue(mokoValue(service.fetch(cacheKey: "c", title: "S", artist: "A", durationMs: 100000))!.found)
        XCTAssertEqual(transport.log.count, count)
    }

    func testCurrentLineIsLastStarted() {
        let lines = [MokoLyricLine(timeMs: 1000, text: "a"), MokoLyricLine(timeMs: 5000, text: "b"), MokoLyricLine(timeMs: 9000, text: "c")]
        XCTAssertNil(MokoLyricsParsing.currentLine(lines, positionMs: 500))
        XCTAssertEqual(MokoLyricsParsing.currentLine(lines, positionMs: 1000), 0)
        XCTAssertEqual(MokoLyricsParsing.currentLine(lines, positionMs: 8999), 1)
        XCTAssertEqual(MokoLyricsParsing.currentLine(lines, positionMs: 60000), 2)
    }
}
