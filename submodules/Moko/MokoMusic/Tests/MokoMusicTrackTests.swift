import Foundation
import XCTest
import MokoMusic

func mokoFixture(_ name: String) throws -> Data {
    let root = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
    return try Data(contentsOf: URL(fileURLWithPath: root).appendingPathComponent("_main/submodules/Moko/MokoMusic/Tests/Fixtures/\(name)"))
}

final class MokoMusicTrackTests: XCTestCase {
    private func transcoding(_ protocolName: String, _ mime: String, _ url: String, snipped: Bool = false) -> [String: Any] {
        return ["url": url, "snipped": snipped, "format": ["protocol": protocolName, "mime_type": mime]]
    }

    private func object(transcodings: [[String: Any]], artwork: Any = "https://i1.sndcdn.com/artworks-x-large.jpg", tags: String = "") -> [String: Any] {
        return [
            "id": 42, "title": "Song", "duration": 180000, "track_authorization": "auth", "permalink_url": "https://soundcloud.com/a/song",
            "artwork_url": artwork, "genre": " Lo-Fi ", "playback_count": 10, "likes_count": 2, "created_at": "2024-01-02T03:04:05Z", "tag_list": tags,
            "user": ["id": 7, "username": "Artist", "avatar_url": "https://i1.sndcdn.com/avatars-y-large.jpg"],
            "media": ["transcodings": transcodings],
        ]
    }

    func testPrefersProgressiveMp3() {
        let track = MokoSoundCloudParser.track(object(transcodings: [
            transcoding("hls", "audio/mp4; codecs=\"mp4a.40.2\"", "https://api/hls-aac"),
            transcoding("progressive", "audio/mpeg", "https://api/progressive"),
            transcoding("hls", "audio/mpeg", "https://api/hls-mp3"),
        ]))
        XCTAssertEqual(track.fileExtension, "mp3")
        XCTAssertFalse(track.isHls)
        XCTAssertEqual(track.transcodingUrl, "https://api/progressive")
        XCTAssertEqual(track.id, "42")
        XCTAssertEqual(track.artist, "Artist")
        XCTAssertEqual(track.artistId, "7")
        XCTAssertEqual(track.genre, "lo-fi")
        XCTAssertEqual(track.createdAt, 1704164645)
    }

    func testFallsBackToHlsAac() {
        let track = MokoSoundCloudParser.track(object(transcodings: [
            transcoding("hls", "audio/mpegurl", "https://api/encrypted"),
            transcoding("hls", "audio/mp4; codecs=\"mp4a.40.2\"", "https://api/hls-aac"),
        ]))
        XCTAssertEqual(track.fileExtension, "m4a")
        XCTAssertTrue(track.isHls)
        XCTAssertEqual(track.transcodingUrl, "https://api/hls-aac")
    }

    func testSkipsSnipped() {
        let track = MokoSoundCloudParser.track(object(transcodings: [transcoding("progressive", "audio/mpeg", "https://api/p", snipped: true)]))
        XCTAssertEqual(track.transcodingUrl, "")
    }

    func testTags() {
        let track = MokoSoundCloudParser.track(object(transcodings: [], tags: "lofi \"chill hop\" Beats"))
        XCTAssertEqual(track.tags, ["lofi", "chill hop", "beats"])
    }

    func testArtworkFallbackAndLarge() {
        let fallback = MokoSoundCloudParser.track(object(transcodings: [], artwork: NSNull()))
        XCTAssertEqual(fallback.artworkUrl, "https://i1.sndcdn.com/avatars-y-large.jpg")
        let track = MokoSoundCloudParser.track(object(transcodings: []))
        XCTAssertEqual(track.largeArtworkUrl, "https://i1.sndcdn.com/artworks-x-t500x500.jpg")
    }

    func testFixtureCollection() throws {
        let page = MokoSoundCloudParser.collection(try mokoFixture("search_tracks.json"))
        XCTAssertFalse(page.tracks.isEmpty)
        for track in page.tracks {
            XCTAssertFalse(track.id.isEmpty)
            XCTAssertFalse(track.transcodingUrl.isEmpty)
        }
        XCTAssertTrue(page.hasNext)
    }

    func testTrackRoundTripsThroughCodable() throws {
        let track = MokoSoundCloudParser.track(object(transcodings: [transcoding("progressive", "audio/mpeg", "https://api/p")]))
        let decoded = try JSONDecoder().decode(MokoMusicTrack.self, from: JSONEncoder().encode(track))
        XCTAssertEqual(decoded, track)
    }
}
