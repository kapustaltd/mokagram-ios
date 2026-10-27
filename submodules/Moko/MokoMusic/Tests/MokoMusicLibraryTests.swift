import Foundation
import XCTest
import SwiftSignalKit
import MokoMusic

private final class FakeSource: MokoRecommendationSource {
    var related: [String: [MokoMusicTrack]] = [:]
    var user: [String: [MokoMusicTrack]] = [:]
    var search: [String: [MokoMusicTrack]] = [:]
    func related(trackId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> { .single(Array((self.related[trackId] ?? []).prefix(limit))) }
    func userTracks(userId: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> { .single(Array((self.user[userId] ?? []).prefix(limit))) }
    func search(_ query: String, limit: Int) -> Signal<[MokoMusicTrack], NoError> { .single(Array((self.search[query] ?? []).prefix(limit))) }
}

final class MokoMusicLibraryTests: XCTestCase {
    private var file: URL!
    private var now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        self.file = FileManager.default.temporaryDirectory.appendingPathComponent("moko-library-\(UUID().uuidString)/library.json")
    }

    private func library() -> MokoMusicLibrary {
        return MokoMusicLibrary(file: self.file, now: { [unowned self] in self.now })
    }

    func testLikesPersistNewestFirst() {
        let library = self.library()
        library.setLiked(mokoTrack("A"), true)
        library.setLiked(mokoTrack("B"), true)
        XCTAssertTrue(library.isLiked("A"))
        let reloaded = self.library()
        XCTAssertEqual(reloaded.likedTracks().map(\.id), ["B", "A"])
        XCTAssertEqual(reloaded.likedTracks().first?.transcodingUrl, "", "stream links are not stored")
        reloaded.setLiked(mokoTrack("B"), false)
        XCTAssertEqual(self.library().likedTracks().map(\.id), ["A"])
    }

    func testDesktopFileFormatReads() throws {
        try FileManager.default.createDirectory(at: self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{\"liked\":[{\"id\":\"9\",\"title\":\"T\",\"artist\":\"A\",\"art\":\"u\",\"link\":\"l\",\"dur\":1000,\"aid\":\"3\",\"genre\":\"g\",\"tags\":[\"x\"],\"plays\":5,\"likes\":1,\"created\":2,\"at\":100}],\"history\":[{\"id\":\"9\",\"aid\":\"3\",\"genre\":\"g\",\"tags\":[],\"dur\":1000,\"l\":900,\"fin\":true,\"at\":100}]}".write(to: self.file, atomically: true, encoding: .utf8)
        let library = self.library()
        XCTAssertEqual(library.likedTracks().map(\.id), ["9"])
        XCTAssertEqual(library.likedTracks().first?.artistId, "3")
        XCTAssertTrue(library.hasTaste)
    }

    func testHistoryCapped() throws {
        let library = self.library()
        let track = mokoTrack("H")
        for _ in 0 ..< 3001 {
            library.recordListen(track, listenedMs: 1000, finished: false)
        }
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: self.file)) as! [String: Any]
        XCTAssertEqual((root["history"] as! [Any]).count, 3000)
    }

    func testNoTasteNote() {
        let result = mokoValue(MokoRecommender.buildForYou(library: self.library(), source: FakeSource(), count: 10, random: { 0.5 }))!
        XCTAssertTrue(result.tracks.isEmpty)
        XCTAssertTrue(result.note.hasPrefix("Пока нечего анализировать"))
    }

    func testSkipPenalizes() {
        let library = self.library()
        library.setLiked(mokoTrack("seed", artist: "s"), true)
        library.recordListen(mokoTrack("skipped", artist: "z"), listenedMs: 5000, finished: false)
        let source = FakeSource()
        source.related["seed"] = [mokoTrack("skipped", artist: "z"), mokoTrack("c1", artist: "x"), mokoTrack("c2", artist: "y"), mokoTrack("c3", artist: "w")]
        let result = mokoValue(MokoRecommender.buildForYou(library: library, source: source, count: 3, random: { 0.5 }))!
        XCTAssertEqual(result.tracks.count, 3)
        XCTAssertFalse(result.tracks.map(\.id).contains("skipped"))
    }

    func testDiversity() {
        let library = self.library()
        library.setLiked(mokoTrack("seed", artist: "s"), true)
        let source = FakeSource()
        source.related["seed"] = (0 ..< 10).map { mokoTrack("x\($0)", artist: "X") } + (0 ..< 2).map { mokoTrack("y\($0)", artist: "Y") }
        let result = mokoValue(MokoRecommender.buildForYou(library: library, source: source, count: 4, random: { 0.5 }))!
        XCTAssertEqual(result.tracks.filter { $0.artistId == "Y" }.count, 2, "\(result.tracks.map(\.id))")
    }

    func testLikedTracksAreNotRecommended() {
        let library = self.library()
        library.setLiked(mokoTrack("seed", artist: "s"), true)
        library.setLiked(mokoTrack("liked", artist: "s"), true)
        let source = FakeSource()
        source.related["seed"] = [mokoTrack("liked", artist: "s"), mokoTrack("new", artist: "n")]
        source.related["liked"] = []
        let result = mokoValue(MokoRecommender.buildForYou(library: library, source: source, count: 5, random: { 0.5 }))!
        XCTAssertEqual(result.tracks.map(\.id), ["new"])
    }
}
