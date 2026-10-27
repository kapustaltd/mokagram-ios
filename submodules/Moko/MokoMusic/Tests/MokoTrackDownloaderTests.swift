import Foundation
import XCTest
import MokoMusic

final class MokoTrackDownloaderTests: XCTestCase {
    private var transport: MokoFakeTransport!
    private var cache: URL!
    private var limit: Int64 = 1 << 30

    override func setUp() {
        super.setUp()
        self.transport = MokoFakeTransport()
        self.cache = FileManager.default.temporaryDirectory.appendingPathComponent("moko-cache-\(UUID().uuidString)")
        let clientIdFile = self.cache.appendingPathComponent("client_id.txt")
        try! FileManager.default.createDirectory(at: self.cache, withIntermediateDirectories: true)
        try! (String(repeating: "c", count: 32)).write(to: clientIdFile, atomically: true, encoding: .utf8)
        self.limit = 1 << 30
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.cache)
        super.tearDown()
    }

    private func downloader() -> MokoTrackDownloader {
        let client = MokoSoundCloudClient(transport: self.transport, clientIdFile: self.cache.appendingPathComponent("client_id.txt"))
        return MokoTrackDownloader(client: client, transport: self.transport, cacheDirectory: self.cache.appendingPathComponent("tracks"), limitBytes: { [unowned self] in self.limit })
    }

    private func trackJson(id: String, transcoding: String, mime: String, protocolName: String) -> String {
        return "{\"id\":\(id),\"title\":\"T\",\"track_authorization\":\"fresh-auth\",\"user\":{\"id\":1,\"username\":\"A\"},\"media\":{\"transcodings\":[{\"url\":\"\(transcoding)\",\"snipped\":false,\"format\":{\"protocol\":\"\(protocolName)\",\"mime_type\":\"\(mime)\"}}]}}"
    }

    private func stale(id: String, hls: Bool) -> MokoMusicTrack {
        var track = MokoSoundCloudParser.track(["id": Int(id)!])
        track.transcodingUrl = "https://api-v2.soundcloud.com/media/stale"
        track.fileExtension = hls ? "m4a" : "mp3"
        track.isHls = hls
        return track
    }

    func testHlsResolvesRelativeAndInit() {
        let playlist = "#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\"\n#EXTINF:10,\nseg1.m4s\n#EXTINF:10,\nhttps://cdn/x/seg2.m4s\n#EXT-X-ENDLIST\n"
        XCTAssertEqual(MokoTrackDownloader.hlsParts(playlist: playlist, base: URL(string: "https://cdn/a/p.m3u8")!).map { $0.absoluteString }, [
            "https://cdn/a/init.mp4", "https://cdn/a/seg1.m4s", "https://cdn/x/seg2.m4s",
        ])
    }

    func testDownloadConcatenatesHls() throws {
        self.transport.on("https://api-v2.soundcloud.com/tracks/5", self.trackJson(id: "5", transcoding: "https://api-v2.soundcloud.com/media/hls-aac", mime: "audio/mp4", protocolName: "hls"))
        self.transport.on("https://api-v2.soundcloud.com/media/hls-aac", "{\"url\":\"https://cdn/a/p.m3u8\"}")
        self.transport.on("https://cdn/a/p.m3u8", "#EXTM3U\n#EXT-X-MAP:URI=\"init.mp4\"\nseg1.m4s\nseg2.m4s\n")
        self.transport.on("https://cdn/a/init.mp4", "A")
        self.transport.on("https://cdn/a/seg1.m4s", "B")
        self.transport.on("https://cdn/a/seg2.m4s", "C")
        let url = try mokoAwait(self.downloader().download(self.stale(id: "5", hls: true)))!.get()
        XCTAssertEqual(url.lastPathComponent, "5.m4a")
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "ABC")
    }

    func testDownloadResolvesStoredTrack() throws {
        self.transport.on("https://api-v2.soundcloud.com/tracks/6", self.trackJson(id: "6", transcoding: "https://api-v2.soundcloud.com/media/progressive", mime: "audio/mpeg", protocolName: "progressive"))
        self.transport.on("https://api-v2.soundcloud.com/media/progressive", "{\"url\":\"https://cdn/file.mp3\"}")
        self.transport.on("https://cdn/file.mp3", "MP3")
        let url = try mokoAwait(self.downloader().download(self.stale(id: "6", hls: false)))!.get()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "MP3")
        XCTAssertEqual(self.transport.paths().first, "https://api-v2.soundcloud.com/tracks/6")
        XCTAssertFalse(self.transport.paths().contains("https://api-v2.soundcloud.com/media/stale"))
        let stream = self.transport.log.first { MokoFakeTransport.key($0) == "https://api-v2.soundcloud.com/media/progressive" }!
        XCTAssertTrue(stream.absoluteString.contains("track_authorization=fresh-auth"))
    }

    func testReturnsCachedWithoutNetwork() throws {
        let downloader = self.downloader()
        let track = self.stale(id: "7", hls: false)
        try FileManager.default.createDirectory(at: self.cache.appendingPathComponent("tracks"), withIntermediateDirectories: true)
        try "cached".write(to: self.cache.appendingPathComponent("tracks/7.mp3"), atomically: true, encoding: .utf8)
        XCTAssertEqual(downloader.cachedFile(for: track)?.lastPathComponent, "7.mp3")
        XCTAssertNotNil(try mokoAwait(downloader.download(track))?.get())
        XCTAssertTrue(self.transport.log.isEmpty)
    }

    func testPruneKeepsProtectedFile() throws {
        let tracks = self.cache.appendingPathComponent("tracks")
        try FileManager.default.createDirectory(at: tracks, withIntermediateDirectories: true)
        let megabyte = Data(count: 1 << 20)
        var files: [URL] = []
        for (index, name) in ["old.mp3", "mid.mp3", "new.mp3"].enumerated() {
            let file = tracks.appendingPathComponent(name)
            try megabyte.write(to: file)
            try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: TimeInterval(1000 * (index + 1)))], ofItemAtPath: file.path)
            files.append(file)
        }
        self.limit = 1 << 20
        self.downloader().prune(protecting: [files[0]])
        XCTAssertTrue(FileManager.default.fileExists(atPath: files[0].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[1].path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: files[2].path))
    }

    func testSegmentFailureLeavesNoFile() {
        self.transport.on("https://api-v2.soundcloud.com/tracks/8", self.trackJson(id: "8", transcoding: "https://api-v2.soundcloud.com/media/hls-aac", mime: "audio/mp4", protocolName: "hls"))
        self.transport.on("https://api-v2.soundcloud.com/media/hls-aac", "{\"url\":\"https://cdn/b/p.m3u8\"}")
        self.transport.on("https://cdn/b/p.m3u8", "#EXTM3U\nseg1.m4s\nseg2.m4s\n")
        self.transport.on("https://cdn/b/seg1.m4s", "B")
        self.transport.on("https://cdn/b/seg2.m4s", status: 500, "")
        guard case .failure(.segmentFailed)? = mokoAwait(self.downloader().download(self.stale(id: "8", hls: true))) else {
            return XCTFail("expected segmentFailed")
        }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: self.cache.appendingPathComponent("tracks").path)) ?? []
        XCTAssertTrue(contents.isEmpty, "\(contents)")
    }

    func testNoStreamUrl() {
        self.transport.on("https://api-v2.soundcloud.com/tracks/9", self.trackJson(id: "9", transcoding: "https://api-v2.soundcloud.com/media/progressive", mime: "audio/mpeg", protocolName: "progressive"))
        self.transport.on("https://api-v2.soundcloud.com/media/progressive", "{}")
        guard case .failure(.noStreamUrl)? = mokoAwait(self.downloader().download(self.stale(id: "9", hls: false))) else {
            return XCTFail("expected noStreamUrl")
        }
    }
}
