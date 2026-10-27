import Foundation
import SwiftSignalKit

public struct MokoHTTPResponse {
    public let status: Int
    public let data: Data
    public let url: URL

    public init(status: Int, data: Data, url: URL) {
        self.status = status
        self.data = data
        self.url = url
    }
}

public enum MokoMusicError: Error, Equatable {
    case noClientId
    case clientIdExpired
    /// `status` 0 means the request did not reach the server.
    case network(status: Int)
    case unavailable
    case noStreamUrl
    case emptyPlaylist
    case segmentFailed
    case writeFailed
}

/// HTTP GET, swappable in tests. Any HTTP status is a response; only a failed request is an error.
public protocol MokoHTTPTransport {
    func get(_ url: URL, headers: [String: String]) -> Signal<MokoHTTPResponse, MokoMusicError>
}

public final class MokoURLSessionTransport: MokoHTTPTransport {
    private let session: URLSession

    public init(timeout: TimeInterval = 20) {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: configuration)
    }

    public func get(_ url: URL, headers: [String: String]) -> Signal<MokoHTTPResponse, MokoMusicError> {
        let session = self.session
        return Signal { subscriber in
            var request = URLRequest(url: url)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            let task = session.dataTask(with: request, completionHandler: { data, response, error in
                guard error == nil, let response = response as? HTTPURLResponse else {
                    subscriber.putError(.network(status: 0))
                    return
                }
                subscriber.putNext(MokoHTTPResponse(status: response.statusCode, data: data ?? Data(), url: response.url ?? url))
                subscriber.putCompletion()
            })
            task.resume()
            return ActionDisposable {
                task.cancel()
            }
        }
    }
}
