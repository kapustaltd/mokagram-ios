import Foundation
import SwiftSignalKit
import MokoMusic

/// Answers by URL without its query; each URL can have a queue of responses (the last one repeats).
final class MokoFakeTransport: MokoHTTPTransport {
    private(set) var log: [URL] = []
    private var responses: [String: [(Int, Data)]] = [:]
    var failing: Set<String> = []

    func on(_ address: String, status: Int = 200, _ body: String) {
        self.on(address, status: status, data: body.data(using: .utf8)!)
    }

    func on(_ address: String, status: Int = 200, data: Data) {
        self.responses[address, default: []].append((status, data))
    }

    func paths() -> [String] {
        return self.log.map { MokoFakeTransport.key($0) }
    }

    static func key(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.query = nil
        return components.string!
    }

    func get(_ url: URL, headers: [String: String]) -> Signal<MokoHTTPResponse, MokoMusicError> {
        self.log.append(url)
        let key = MokoFakeTransport.key(url)
        if self.failing.contains(key) {
            return .fail(.network(status: 0))
        }
        guard var queue = self.responses[key], !queue.isEmpty else {
            return .single(MokoHTTPResponse(status: 404, data: Data(), url: url))
        }
        let (status, data) = queue.count > 1 ? queue.removeFirst() : queue[0]
        self.responses[key] = queue
        return .single(MokoHTTPResponse(status: status, data: data, url: url))
    }
}

/// Runs a signal that completes synchronously (fake transport) and returns its outcome.
func mokoAwait<T, E>(_ signal: Signal<T, E>) -> Result<T, E>? {
    var result: Result<T, E>?
    let _ = signal.start(next: { result = .success($0) }, error: { result = .failure($0) })
    return result
}

/// The value of a synchronously completing signal that cannot fail.
func mokoValue<T>(_ signal: Signal<T, NoError>) -> T? {
    var value: T?
    let _ = signal.start(next: { value = $0 })
    return value
}
