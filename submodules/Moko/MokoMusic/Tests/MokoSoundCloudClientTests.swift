import Foundation
import XCTest
import MokoMusic

final class MokoSoundCloudClientTests: XCTestCase {
    private var transport: MokoFakeTransport!
    private var clientIdFile: URL!
    private let clientId = String(repeating: "a", count: 31) + "Z"
    private let newClientId = String(repeating: "b", count: 31) + "Y"

    override func setUp() {
        super.setUp()
        self.transport = MokoFakeTransport()
        self.clientIdFile = FileManager.default.temporaryDirectory.appendingPathComponent("moko-client-\(UUID().uuidString).txt")
    }

    private func client() -> MokoSoundCloudClient {
        return MokoSoundCloudClient(transport: self.transport, clientIdFile: self.clientIdFile)
    }

    private func home(id: String) {
        self.transport.on("https://soundcloud.com/", "<script src=\"https://a-v2.sndcdn.com/assets/a.js\"></script><script src=\"https://a-v2.sndcdn.com/assets/b.js\"></script>")
        self.transport.on("https://a-v2.sndcdn.com/assets/a.js", "x={client_id:\"\(id)\"}")
        self.transport.on("https://a-v2.sndcdn.com/assets/b.js", "nothing here")
    }

    private let emptyPage = "{\"collection\":[],\"next_href\":null}"

    func testDiscoversClientIdFromLastScript() throws {
        self.home(id: self.clientId)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", self.emptyPage)
        let result = mokoAwait(self.client().search("lofi", offset: 0))
        XCTAssertNotNil(try result?.get())
        XCTAssertEqual(self.transport.paths(), [
            "https://soundcloud.com/",
            "https://a-v2.sndcdn.com/assets/b.js",
            "https://a-v2.sndcdn.com/assets/a.js",
            "https://api-v2.soundcloud.com/search/tracks",
        ])
        XCTAssertTrue(self.transport.log.last!.absoluteString.contains("client_id=\(self.clientId)"))
        XCTAssertEqual(try String(contentsOf: self.clientIdFile, encoding: .utf8), self.clientId)
    }

    func testUsesCachedClientId() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", self.emptyPage)
        _ = mokoAwait(self.client().search("lofi", offset: 0))
        XCTAssertEqual(self.transport.paths(), ["https://api-v2.soundcloud.com/search/tracks"])
    }

    func testRefreshesClientIdOnceOn401() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.home(id: self.newClientId)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", status: 401, "")
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", self.emptyPage)
        XCTAssertNotNil(try mokoAwait(self.client().search("lofi", offset: 0))?.get())
        XCTAssertEqual(self.transport.paths().filter { $0 == "https://soundcloud.com/" }.count, 1)
        XCTAssertTrue(self.transport.log.last!.absoluteString.contains("client_id=\(self.newClientId)"))
    }

    func testGivesUpAfterSecond401() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.home(id: self.newClientId)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", status: 403, "")
        let result = mokoAwait(self.client().search("lofi", offset: 0))
        guard case .failure(.clientIdExpired)? = result else {
            return XCTFail("expected clientIdExpired, got \(String(describing: result))")
        }
        XCTAssertEqual(self.transport.paths().filter { $0 == "https://api-v2.soundcloud.com/search/tracks" }.count, 2)
    }

    func testNoClientIdWhenHomeHasNone() {
        self.transport.on("https://soundcloud.com/", "<html></html>")
        guard case .failure(.noClientId)? = mokoAwait(self.client().search("lofi", offset: 0)) else {
            return XCTFail("expected noClientId")
        }
    }

    func testPagingOffsets() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", data: try mokoFixture("search_tracks.json"))
        let page = try mokoAwait(self.client().search("lofi", offset: 0))!.get()
        XCTAssertEqual(page.nextOffset, 20)
        XCTAssertFalse(page.tracks.isEmpty)
        let query = URLComponents(url: self.transport.log.last!, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertEqual(query.first(where: { $0.name == "limit" })?.value, "20")
        XCTAssertEqual(query.first(where: { $0.name == "q" })?.value, "lofi")
        let transport = MokoFakeTransport()
        transport.on("https://api-v2.soundcloud.com/search/tracks", self.emptyPage)
        let last = try mokoAwait(MokoSoundCloudClient(transport: transport, clientIdFile: self.clientIdFile).search("lofi", offset: 40))!.get()
        XCTAssertNil(last.nextOffset)
    }

    func testResolveUnavailable() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.transport.on("https://api-v2.soundcloud.com/tracks/1", "{\"id\":1,\"media\":{\"transcodings\":[]}}")
        let track = MokoSoundCloudParser.track(["id": 1])
        guard case .failure(.unavailable)? = mokoAwait(self.client().resolve(track)) else {
            return XCTFail("expected unavailable")
        }
    }

    func testNetworkStatusError() throws {
        try self.clientId.write(to: self.clientIdFile, atomically: true, encoding: .utf8)
        self.transport.on("https://api-v2.soundcloud.com/search/tracks", status: 500, "")
        guard case .failure(.network(status: 500))? = mokoAwait(self.client().search("x", offset: 0)) else {
            return XCTFail("expected network(500)")
        }
    }
}
