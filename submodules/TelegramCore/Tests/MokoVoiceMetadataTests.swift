import Foundation
import XCTest
@testable import TelegramCore

final class MokoVoiceMetadataTests: XCTestCase {
    func testOpusHeadersAndTruncation() {
        var data = Data("OpusHead".utf8)
        data.append(contentsOf: [1, 1, 0, 0, 0x80, 0xbb, 0, 0])
        data.append(Data("OpusTags".utf8))
        data.append(contentsOf: [4, 0, 0, 0])
        data.append(Data("test".utf8))
        let metadata = MokoVoiceMetadataReader.parse(data)
        XCTAssertEqual(metadata.sampleRate, 48000)
        XCTAssertEqual(metadata.encoder, "test")
        XCTAssertNil(MokoVoiceMetadataReader.parse(Data("OpusHead".utf8)).sampleRate)
        XCTAssertNil(MokoVoiceMetadataReader.parse(data.dropLast()).encoder)
        XCTAssertNil(MokoVoiceMetadataReader.parse(Data()).encoder)
    }
}
