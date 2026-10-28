import Foundation
import SwiftSignalKit
import MokoCore

/// Where the client talks to. The key is a secret: it is never written in source, it comes from the
/// build (Info.plist key `MokoSaveinatorApiKey`) or, for development, from the app group defaults
/// (`mokoGram.saveinator.apiKey`). Without a key the offer is not made.
public struct MokoSaveinatorConfiguration {
    public static let defaultBaseUrl = "https://saveinator-hooks.xdshka.party"
    public static let infoKeyApiKey = "MokoSaveinatorApiKey"
    public static let infoKeyBaseUrl = "MokoSaveinatorApiUrl"
    public static let defaultsKeyApiKey = "mokoGram.saveinator.apiKey"
    public static let defaultsKeyBaseUrl = "mokoGram.saveinator.apiUrl"

    public var baseUrl: URL
    public var apiKey: String

    public init(baseUrl: URL, apiKey: String) {
        self.baseUrl = baseUrl
        self.apiKey = apiKey
    }

    public static func current(bundle: Bundle = .main, defaults: UserDefaults = MokoStorage.defaults) -> MokoSaveinatorConfiguration? {
        func value(_ infoKey: String, _ defaultsKey: String) -> String? {
            let candidates = [bundle.object(forInfoDictionaryKey: infoKey) as? String, defaults.string(forKey: defaultsKey)]
            for candidate in candidates {
                if let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !candidate.isEmpty, !candidate.hasPrefix("$(") {
                    return candidate
                }
            }
            return nil
        }
        guard let key = value(infoKeyApiKey, defaultsKeyApiKey) else {
            return nil
        }
        let base = value(infoKeyBaseUrl, defaultsKeyBaseUrl) ?? defaultBaseUrl
        guard let url = URL(string: base), url.scheme == "https" else {
            return nil
        }
        return MokoSaveinatorConfiguration(baseUrl: url, apiKey: key)
    }
}

/// HTTP used by the client, swappable in tests. `status` 0 means the request did not reach the server.
public protocol MokoSaveinatorTransport: AnyObject {
    func send(method: String, path: String, body: Data?, completion: @escaping (_ status: Int, _ data: Data) -> Void) -> Disposable
    /// Streams the response to `file` and reports the bytes written so far.
    func download(path: String, to file: URL, progress: @escaping (Int64) -> Void, completion: @escaping (_ status: Int, _ contentType: String, _ received: Int64) -> Void) -> Disposable
}

public final class MokoSaveinatorURLSessionTransport: NSObject, MokoSaveinatorTransport {
    private static let userAgent = "Saveinator-mokaGram/1.0"
    private let configuration: MokoSaveinatorConfiguration
    private let jsonTimeout: TimeInterval = 30.0

    public init(configuration: MokoSaveinatorConfiguration) {
        self.configuration = configuration
        super.init()
    }

    private func request(method: String, path: String) -> URLRequest? {
        guard let url = URL(string: self.configuration.baseUrl.absoluteString + path), url.host == self.configuration.baseUrl.host else {
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: self.jsonTimeout)
        request.httpMethod = method
        request.setValue("Bearer " + self.configuration.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue(MokoSaveinatorURLSessionTransport.userAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    public func send(method: String, path: String, body: Data?, completion: @escaping (Int, Data) -> Void) -> Disposable {
        guard var request = self.request(method: method, path: path) else {
            completion(0, Data())
            return EmptyDisposable
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let delegate = NoRedirectDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request, completionHandler: { data, response, _ in
            session.finishTasksAndInvalidate()
            completion((response as? HTTPURLResponse)?.statusCode ?? 0, data ?? Data())
        })
        task.resume()
        return ActionDisposable {
            task.cancel()
            session.invalidateAndCancel()
        }
    }

    public func download(path: String, to file: URL, progress: @escaping (Int64) -> Void, completion: @escaping (Int, String, Int64) -> Void) -> Disposable {
        guard var request = self.request(method: "GET", path: path) else {
            completion(0, "", 0)
            return EmptyDisposable
        }
        request.timeoutInterval = 60.0
        let delegate = DownloadDelegate(destination: file, progress: progress, completion: completion)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: request)
        task.resume()
        return ActionDisposable {
            task.cancel()
            session.invalidateAndCancel()
        }
    }
}

/// The key must not follow a redirect to another host.
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let destination: URL
    private let progress: (Int64) -> Void
    private let completion: (Int, String, Int64) -> Void
    private var moved: Int64?
    private var completed = false

    init(destination: URL, progress: @escaping (Int64) -> Void, completion: @escaping (Int, String, Int64) -> Void) {
        self.destination = destination
        self.progress = progress
        self.completion = completion
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.progress(totalBytesWritten)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        try? FileManager.default.removeItem(at: self.destination)
        do {
            try FileManager.default.moveItem(at: location, to: self.destination)
            let size = (try? FileManager.default.attributesOfItem(atPath: self.destination.path)[.size] as? NSNumber)?.int64Value ?? 0
            self.moved = size
        } catch {
            self.moved = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.completed else {
            return
        }
        self.completed = true
        let response = task.response as? HTTPURLResponse
        let status = response?.statusCode ?? 0
        let contentType = (response?.value(forHTTPHeaderField: "Content-Type") ?? "").split(separator: ";").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if error != nil || self.moved == nil {
            self.completion(status, contentType, -1)
        } else {
            self.completion(status, contentType, self.moved ?? 0)
        }
        session.finishTasksAndInvalidate()
    }
}
