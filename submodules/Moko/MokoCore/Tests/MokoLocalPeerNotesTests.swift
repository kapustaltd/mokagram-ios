import Foundation
import XCTest
import MokoCore

final class MokoLocalPeerNotesTests: XCTestCase {
    func testPersistenceIsolationAndRemoval() {
        let suite = "MokoLocalPeerNotesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        MokoStorage._resetForTesting(defaults: defaults)
        defer { defaults.removePersistentDomain(forName: suite) }

        MokoLocalPeerNotes.save(accountId: 1, peerId: 2, tag: "  first   tag ", note: " note ")
        XCTAssertEqual(MokoLocalPeerNotes.load(accountId: 1, peerId: 2), MokoLocalPeerNote(tag: "first tag", note: "note"))
        XCTAssertEqual(MokoLocalPeerNotes.load(accountId: 2, peerId: 2), MokoLocalPeerNote(tag: "", note: ""))
        XCTAssertEqual(MokoLocalPeerNotes.load(accountId: 1, peerId: 3), MokoLocalPeerNote(tag: "", note: ""))

        MokoLocalPeerNotes.save(accountId: 1, peerId: 2, tag: String(repeating: "x", count: 30), note: String(repeating: "y", count: 2100))
        let value = MokoLocalPeerNotes.load(accountId: 1, peerId: 2)
        XCTAssertEqual(value.tag.count, 24)
        XCTAssertEqual(value.note.count, 2000)

        MokoLocalPeerNotes.save(accountId: 1, peerId: 2, tag: " ", note: " ")
        XCTAssertEqual(MokoLocalPeerNotes.load(accountId: 1, peerId: 2), MokoLocalPeerNote(tag: "", note: ""))
    }
}
