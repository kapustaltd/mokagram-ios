import Foundation
import XCTest
import SwiftSignalKit
import MokoCore
@testable import MokoSaveinator

private let validId = "0123abcd-0123-abcd-0123-0123abcd0123"

private final class FakeTransport: MokoSaveinatorTransport {
    struct Reply {
        var status: Int
        var body: String
    }

    struct Download {
        var status: Int
        var contentType: String
        var content: Data
    }

    private let lock = NSLock()
    var posts: [(path: String, body: [String: Any])] = []
    var gets: [String] = []
    /// Answers for GET /api/v1/downloads/<id>, one per call; the last repeats.
    var pollReplies: [Reply] = []
    var createReply = Reply(status: 202, body: "{\"id\":\"\(validId)\",\"status\":\"queued\"}")
    var downloads: [String: Download] = [:]

    func send(method: String, path: String, body: Data?, completion: @escaping (Int, Data) -> Void) -> Disposable {
        self.lock.lock()
        let reply: Reply
        if method == "POST" {
            self.posts.append((path, ((try? JSONSerialization.jsonObject(with: body ?? Data())) as? [String: Any]) ?? [:]))
            reply = self.createReply
        } else {
            self.gets.append(path)
            reply = self.pollReplies.count > 1 ? self.pollReplies.removeFirst() : (self.pollReplies.first ?? Reply(status: 500, body: ""))
        }
        self.lock.unlock()
        DispatchQueue.global().async {
            completion(reply.status, reply.body.data(using: .utf8) ?? Data())
        }
        return EmptyDisposable
    }

    func download(path: String, to file: URL, progress: @escaping (Int64) -> Void, completion: @escaping (Int, String, Int64) -> Void) -> Disposable {
        let item = self.downloads[path]
        DispatchQueue.global().async {
            guard let item else {
                completion(404, "", -1)
                return
            }
            try? item.content.write(to: file)
            progress(Int64(item.content.count))
            completion(item.status, item.contentType, Int64(item.content.count))
        }
        return EmptyDisposable
    }
}

final class MokoSaveinatorClientTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        super.setUp()
        self.root = FileManager.default.temporaryDirectory.appendingPathComponent("moko-saveinator-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: self.root)
        super.tearDown()
    }

    private func run(_ transport: FakeTransport, timeout: TimeInterval = 10.0) -> (events: [MokoSaveinatorEvent], error: MokoSaveinatorError?) {
        let done = expectation(description: "done")
        var events: [MokoSaveinatorEvent] = []
        var failure: MokoSaveinatorError?
        let disposable = MokoSaveinator.download(link: "https://youtu.be/x", choice: .make(media: 1, quality: 2), transport: transport, root: self.root).start(next: { event in
            events.append(event)
        }, error: { error in
            failure = error
            done.fulfill()
        }, completed: {
            done.fulfill()
        })
        wait(for: [done], timeout: timeout)
        disposable.dispose()
        return (events, failure)
    }

    private func readyBody(files: [(String, String, Int)]) -> String {
        let list = files.enumerated().map { index, file in
            "{\"url\":\"/api/v1/downloads/\(validId)/files/\(index)\",\"content_type\":\"\(file.1)\",\"size\":\(file.2)}"
        }.joined(separator: ",")
        return "{\"id\":\"\(validId)\",\"status\":\"ready\",\"files\":[\(list)]}"
    }

    func testRequestShape() {
        let transport = FakeTransport()
        transport.pollReplies = [.init(status: 200, body: "{\"status\":\"failed\",\"error\":\"no_media\"}")]
        _ = self.run(transport)
        XCTAssertEqual(transport.posts.first?.path, "/api/v1/downloads")
        XCTAssertEqual(transport.posts.first?.body["url"] as? String, "https://youtu.be/x")
        XCTAssertEqual(transport.posts.first?.body["media"] as? String, "video")
        XCTAssertEqual(transport.posts.first?.body["max_height"] as? Int, 720)
        XCTAssertEqual(transport.posts.first?.body["limit"] as? Int, 10)
    }

    func testVideoAndCaption() throws {
        let transport = FakeTransport()
        transport.createReply = .init(status: 200, body: readyBody(files: [("", "video/mp4", 3), ("", "text/plain", 6)]))
        transport.downloads["/api/v1/downloads/\(validId)/files/0"] = .init(status: 200, contentType: "video/mp4", content: Data([1, 2, 3]))
        transport.downloads["/api/v1/downloads/\(validId)/files/1"] = .init(status: 200, contentType: "text/plain", content: "hello\n".data(using: .utf8)!)
        let result = self.run(transport)
        XCTAssertNil(result.error)
        guard case let .finished(finished)? = result.events.last(where: { if case .finished = $0 { return true } else { return false } }) else {
            return XCTFail("no result")
        }
        XCTAssertEqual(finished.files.count, 1)
        XCTAssertEqual(finished.files[0].contentType, "video/mp4")
        XCTAssertEqual(finished.files[0].url.pathExtension, "mp4")
        XCTAssertEqual(try Data(contentsOf: finished.files[0].url), Data([1, 2, 3]))
        XCTAssertEqual(finished.text, "hello")
        XCTAssertTrue(result.events.contains(.progress(1.0)))
    }

    func testPollsUntilReady() {
        let transport = FakeTransport()
        transport.pollReplies = [
            .init(status: 202, body: "{\"status\":\"running\"}"),
            .init(status: 200, body: readyBody(files: [("", "image/jpeg", 2)])),
        ]
        transport.downloads["/api/v1/downloads/\(validId)/files/0"] = .init(status: 200, contentType: "image/jpeg", content: Data([9, 9]))
        let result = self.run(transport)
        XCTAssertNil(result.error)
        XCTAssertEqual(transport.gets.count, 2)
    }

    func testRetriesServerErrorWhilePolling() {
        let transport = FakeTransport()
        transport.pollReplies = [
            .init(status: 503, body: ""),
            .init(status: 200, body: readyBody(files: [("", "image/jpeg", 1)])),
        ]
        transport.downloads["/api/v1/downloads/\(validId)/files/0"] = .init(status: 200, contentType: "image/jpeg", content: Data([7]))
        XCTAssertNil(self.run(transport).error)
    }

    func testServerErrorCodeIsReported() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 400, body: "{\"error\":\"unsupported_url\"}")
        XCTAssertEqual(self.run(transport).error, MokoSaveinatorError(code: "unsupported_url"))
    }

    func testHttpStatusMapping() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 429, body: "")
        XCTAssertEqual(self.run(transport).error?.code, "capacity_exceeded")
        transport.createReply = .init(status: 401, body: "")
        XCTAssertEqual(self.run(transport).error?.code, "unauthorized")
    }

    func testRejectsInvalidId() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 202, body: "{\"id\":\"../../etc\",\"status\":\"queued\"}")
        XCTAssertEqual(self.run(transport).error?.code, "failed")
    }

    func testRejectsFileOutsideDownloadPrefix() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 200, body: "{\"id\":\"\(validId)\",\"status\":\"ready\",\"files\":[{\"url\":\"/other/0\",\"content_type\":\"video/mp4\",\"size\":3}]}")
        XCTAssertEqual(self.run(transport).error?.code, "failed")
    }

    func testRejectsTooLargeAndUnknownType() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 200, body: readyBody(files: [("", "video/mp4", 5 * 1024 * 1024 * 1024)]))
        XCTAssertEqual(self.run(transport).error?.code, "too_large")
        // The server serves files up to 2560 MB; they must pass the client's sanity check.
        transport.createReply = .init(status: 200, body: readyBody(files: [("", "video/mp4", 2560 * 1024 * 1024)]))
        XCTAssertNotEqual(self.run(transport).error?.code, "too_large")
        transport.createReply = .init(status: 200, body: readyBody(files: [("", "application/x-evil", 3)]))
        XCTAssertEqual(self.run(transport).error?.code, "failed")
    }

    func testSizeOrTypeMismatchFailsAndCleansUp() {
        let transport = FakeTransport()
        transport.createReply = .init(status: 200, body: readyBody(files: [("", "video/mp4", 3)]))
        transport.downloads["/api/v1/downloads/\(validId)/files/0"] = .init(status: 200, contentType: "video/mp4", content: Data([1, 2]))
        XCTAssertEqual(self.run(transport).error?.code, "failed")
        XCTAssertFalse(FileManager.default.fileExists(atPath: self.root.appendingPathComponent(validId).path))
    }

    func testMissingTransportIsNotConfigured() {
        let done = expectation(description: "error")
        var failure: MokoSaveinatorError?
        let disposable = MokoSaveinator.download(link: "https://youtu.be/x", choice: .make(media: 0, quality: 0), transport: nil, root: self.root).start(error: { error in
            failure = error
            done.fulfill()
        })
        wait(for: [done], timeout: 2.0)
        disposable.dispose()
        XCTAssertEqual(failure, .notConfigured)
    }

    func testConfigurationNeedsKeyAndHttps() {
        let defaults = UserDefaults(suiteName: "moko-saveinator-\(UUID().uuidString)")!
        XCTAssertNil(MokoSaveinatorConfiguration.current(bundle: Bundle(for: FakeBundleMarker.self), defaults: defaults))
        defaults.set("secret", forKey: MokoSaveinatorConfiguration.defaultsKeyApiKey)
        XCTAssertEqual(MokoSaveinatorConfiguration.current(bundle: Bundle(for: FakeBundleMarker.self), defaults: defaults)?.baseUrl.absoluteString, MokoSaveinatorConfiguration.defaultBaseUrl)
        defaults.set("http://insecure.example", forKey: MokoSaveinatorConfiguration.defaultsKeyBaseUrl)
        XCTAssertNil(MokoSaveinatorConfiguration.current(bundle: Bundle(for: FakeBundleMarker.self), defaults: defaults))
    }

    func testErrorTextCoversCodes() {
        XCTAssertEqual(MokoSaveinator.errorText(code: "capacity_exceeded"), "Сервис скачивания занят. Попробуйте чуть позже.")
        XCTAssertEqual(MokoSaveinator.errorText(code: "weird"), "Не удалось скачать медиа по этой ссылке.")
        for code in ["capacity_exceeded", "unsupported_url", "no_media", "too_large", "timeout", "not_found", "failed"] {
            XCTAssertNotEqual(MokoStrings.tr(MokoSaveinator.errorText(code: code), languageCode: "en"), MokoSaveinator.errorText(code: code), code)
        }
    }
}

private final class FakeBundleMarker {}
