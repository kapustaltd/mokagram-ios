import Foundation
import XCTest
import MokoMusic

func mokoTrack(_ id: String, artist: String = "a1", title: String? = nil, genre: String = "", tags: [String] = [], durationMs: Int = 200000, plays: Int64 = 0, likes: Int64 = 0) -> MokoMusicTrack {
    return MokoMusicTrack(id: id, title: title ?? "Track \(id)", artist: "Artist \(artist)", artworkUrl: "", permalink: "", transcodingUrl: "https://api/\(id)", authorization: "auth", fileExtension: "mp3", durationMs: durationMs, isHls: false, artistId: artist, genre: genre, tags: tags, playbackCount: plays, likesCount: likes, createdAt: 0)
}

final class MokoMusicQueueTests: XCTestCase {
    private func queue(_ count: Int, start: Int) -> MokoMusicQueue {
        return MokoMusicQueue(tracks: (0 ..< count).map { mokoTrack("\($0)") }, startIndex: start)
    }

    func testRegularNextAndEnd() {
        var q = self.queue(3, start: 2)
        XCTAssertNil(q.step(1, reason: .user, random: { _ in 0 }))
        q = self.queue(3, start: 2)
        q.looping = .all
        XCTAssertEqual(q.step(1, reason: .user, random: { _ in 0 }), 0)
        XCTAssertEqual(q.index, 0)
    }

    func testPreviousStaysAtStart() {
        var q = self.queue(3, start: 0)
        XCTAssertEqual(q.step(-1, reason: .user, random: { _ in 0 }), 0)
    }

    func testReversedOrderWalksBackwards() {
        var q = self.queue(3, start: 1)
        q.order = .reversed
        XCTAssertEqual(q.step(1, reason: .user, random: { _ in 0 }), 0)
    }

    func testAutoplayOffStops() {
        var q = self.queue(3, start: 0)
        XCTAssertNil(q.step(1, reason: .trackEnded(autoplay: false), random: { _ in 0 }))
        var q2 = self.queue(3, start: 0)
        XCTAssertEqual(q2.step(1, reason: .trackEnded(autoplay: true), random: { _ in 0 }), 1)
    }

    func testSkipsFailedTrack() {
        var q = self.queue(3, start: 0)
        q.markFailed(1)
        XCTAssertEqual(q.step(1, reason: .user, random: { _ in 0 }), 2)
    }

    func testStopsWhenAllFail() {
        var q = self.queue(3, start: 0)
        q.looping = .all
        q.markFailed(0)
        q.markFailed(1)
        q.markFailed(2)
        XCTAssertNil(q.step(1, reason: .user, random: { _ in 0 }))
    }

    func testRandomPicksAnotherPlayableTrack() {
        var q = self.queue(4, start: 0)
        q.order = .random
        q.markFailed(1)
        XCTAssertEqual(q.step(1, reason: .user, random: { _ in 0 }), 2)
    }

    func testItemLoopingAdvancesOnUserNext() {
        // Repeating one track is done by the app player itself; an explicit "next" still moves on.
        var q = self.queue(3, start: 0)
        q.looping = .item
        XCTAssertEqual(q.step(1, reason: .user, random: { _ in 0 }), 1)
    }

    func testJumpMoveRemove() {
        var q = self.queue(4, start: 0)
        q.jump(to: 2)
        XCTAssertEqual(q.index, 2)
        q.move(from: 2, to: 0)
        XCTAssertEqual(q.tracks.map(\.id), ["2", "0", "1", "3"])
        XCTAssertEqual(q.index, 0)
        q.remove(at: 1)
        XCTAssertEqual(q.tracks.map(\.id), ["2", "1", "3"])
        XCTAssertEqual(q.index, 0)
    }
}
