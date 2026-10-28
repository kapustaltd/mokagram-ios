import Foundation
import SwiftSignalKit
import MokoCore

/// A failure; `code` is a Saveinator error code (`capacity_exceeded`, `unsupported_url`, `no_media`,
/// `too_large`, `timeout`, `not_found`, `unauthorized`, `failed`, ...).
public struct MokoSaveinatorError: Error, Equatable {
    public let code: String

    public init(code: String) {
        self.code = code
    }

    public static let failed = MokoSaveinatorError(code: "failed")
    public static let notConfigured = MokoSaveinatorError(code: "not_configured")
}

public struct MokoSaveinatorFile: Equatable {
    public let url: URL
    public let contentType: String

    public init(url: URL, contentType: String) {
        self.url = url
        self.contentType = contentType
    }
}

public struct MokoSaveinatorResult: Equatable {
    /// Holds `files`; the caller removes it when it is done with them.
    public let directory: URL
    public let files: [MokoSaveinatorFile]
    /// The text part of the answer (caption), when the service returned one.
    public let text: String

    public init(directory: URL, files: [MokoSaveinatorFile], text: String) {
        self.directory = directory
        self.files = files
        self.text = text
    }
}

public enum MokoSaveinatorEvent: Equatable {
    /// 0...1; stays at 0 while the service prepares the media.
    case progress(Double)
    case finished(MokoSaveinatorResult)
}

public enum MokoSaveinator {
    static let maxFiles = 10
    static let maxJsonSize = 64 * 1024
    static let maxFileSize: Int64 = 4 * 1024 * 1024 * 1024
    static let maxPollFailures = 3
    static let overallTimeout: TimeInterval = 30.0 * 60.0

    private static let extensions: [String: String] = [
        "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif",
        "video/mp4": "mp4", "video/webm": "webm", "video/quicktime": "mov", "video/x-matroska": "mkv",
        "audio/mpeg": "mp3", "audio/mp4": "m4a", "audio/ogg": "ogg", "audio/wav": "wav", "audio/flac": "flac",
        "text/plain": "txt",
    ]

    static func fileExtension(forContentType contentType: String) -> String? {
        return extensions[contentType]
    }

    /// Short first checks: short clips are ready within a second or two.
    static func pollDelay(_ polls: Int) -> Double {
        return polls < 3 ? 0.7 : (polls < 8 ? 1.2 : 2.0)
    }

    public static var rootDirectory: URL {
        return FileManager.default.temporaryDirectory.appendingPathComponent("mokagram-saveinator")
    }

    /// Removes what earlier sessions left behind; call once per launch.
    public static func cleanupRoot() {
        try? FileManager.default.removeItem(at: rootDirectory)
    }

    public static func download(link: String, choice: MokoSaveinatorChoice, transport: MokoSaveinatorTransport?, root: URL = MokoSaveinator.rootDirectory) -> Signal<MokoSaveinatorEvent, MokoSaveinatorError> {
        return Signal { subscriber in
            guard let transport else {
                subscriber.putError(.notConfigured)
                return EmptyDisposable
            }
            let job = Job(link: link, choice: choice, transport: transport, root: root, subscriber: subscriber)
            job.start()
            return ActionDisposable {
                job.cancel()
            }
        }
    }

    /// Message for the user for an error code; Russian keys of the string table.
    public static func errorText(code: String) -> String {
        switch code {
        case "capacity_exceeded", "shutting_down":
            return "Сервис скачивания занят. Попробуйте чуть позже."
        case "unsupported_url":
            return "Эта ссылка пока не поддерживается."
        case "no_media":
            return "Медиа для скачивания не найдено."
        case "too_large":
            return "Медиафайл превышает ограничение размера на сервере."
        case "timeout":
            return "Скачивание заняло слишком много времени. Попробуйте позже."
        case "not_found":
            return "Срок хранения истёк или результат недоступен."
        default:
            return "Не удалось скачать медиа по этой ссылке."
        }
    }

    private struct PlannedFile {
        let path: String
        let contentType: String
        let fileExtension: String
        let size: Int64
    }

    private final class Job {
        private let queue = DispatchQueue(label: "mokagram.saveinator")
        private let link: String
        private let choice: MokoSaveinatorChoice
        private let transport: MokoSaveinatorTransport
        private let root: URL
        private let subscriber: Subscriber<MokoSaveinatorEvent, MokoSaveinatorError>

        private var finished = false
        private var request: Disposable?
        private var id = ""
        private var directory: URL?
        private var plan: [PlannedFile] = []
        private var totalBytes: Int64 = 0
        private var completedBytes: Int64 = 0
        private var next = 0
        private var files: [MokoSaveinatorFile] = []
        private var text = ""
        private var polls = 0
        private var pollFailures = 0
        private var deadline: DispatchWorkItem?

        init(link: String, choice: MokoSaveinatorChoice, transport: MokoSaveinatorTransport, root: URL, subscriber: Subscriber<MokoSaveinatorEvent, MokoSaveinatorError>) {
            self.link = link
            self.choice = choice
            self.transport = transport
            self.root = root
            self.subscriber = subscriber
        }

        func start() {
            self.queue.async { [self] in
                let deadline = DispatchWorkItem { [weak self] in
                    self?.fail("timeout")
                }
                self.deadline = deadline
                self.queue.asyncAfter(deadline: .now() + MokoSaveinator.overallTimeout, execute: deadline)
                self.subscriber.putNext(.progress(0.0))
                self.create()
            }
        }

        func cancel() {
            self.queue.async {
                guard !self.finished else {
                    return
                }
                self.finished = true
                self.deadline?.cancel()
                self.request?.dispose()
                self.removeDirectory()
            }
        }

        private func removeDirectory() {
            if let directory = self.directory {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        private func fail(_ code: String) {
            guard !self.finished else {
                return
            }
            self.finished = true
            self.deadline?.cancel()
            self.request?.dispose()
            self.request = nil
            self.removeDirectory()
            self.subscriber.putError(MokoSaveinatorError(code: code))
        }

        private static func httpError(_ status: Int) -> String {
            switch status {
            case 401:
                return "unauthorized"
            case 404:
                return "not_found"
            case 429:
                return "capacity_exceeded"
            default:
                return "failed"
            }
        }

        /// One JSON request. `retry` is set for polling: a blip of the network or a server error
        /// is tried again a few times instead of dropping the download.
        private func sendJson(method: String, path: String, body: Data?, retry: (() -> Void)? = nil, done: @escaping ([String: Any]) -> Void) {
            self.request = self.transport.send(method: method, path: path, body: body, completion: { [weak self] status, data in
                guard let self else {
                    return
                }
                self.queue.async {
                    guard !self.finished else {
                        return
                    }
                    self.request = nil
                    let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                    if status == 200 || status == 202 {
                        if data.count > MokoSaveinator.maxJsonSize || object == nil || object?.isEmpty == true {
                            self.fail("failed")
                        } else {
                            done(object ?? [:])
                        }
                    } else if status == 400, let code = object?["error"] as? String {
                        self.fail(code)
                    } else if let retry, status == 0 || status >= 500, self.pollFailures < MokoSaveinator.maxPollFailures {
                        self.pollFailures += 1
                        retry()
                    } else {
                        self.fail(Job.httpError(status))
                    }
                }
            })
        }

        private func create() {
            var fields: [String: Any] = ["url": self.link, "media": self.choice.media, "limit": MokoSaveinator.maxFiles]
            if self.choice.maxHeight > 0 {
                fields["max_height"] = self.choice.maxHeight
            }
            guard let body = try? JSONSerialization.data(withJSONObject: fields) else {
                self.fail("failed")
                return
            }
            self.sendJson(method: "POST", path: "/api/v1/downloads", body: body, done: { [weak self] object in
                guard let self else {
                    return
                }
                let id = object["id"] as? String ?? ""
                guard id.count == 36, id.allSatisfy({ $0.isHexDigit || $0 == "-" }), id == id.lowercased() else {
                    self.fail("failed")
                    return
                }
                self.id = id
                self.handle(object)
            })
        }

        private func handle(_ object: [String: Any]) {
            let status = object["status"] as? String ?? ""
            switch status {
            case "ready":
                self.ready(object)
            case "queued", "running":
                let delay = MokoSaveinator.pollDelay(self.polls)
                self.polls += 1
                self.queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.poll()
                }
            default:
                let code = object["error"] as? String ?? ""
                self.fail(code.isEmpty ? "failed" : code)
            }
        }

        private func poll() {
            guard !self.finished else {
                return
            }
            self.sendJson(method: "GET", path: "/api/v1/downloads/" + self.id, body: nil, retry: { [weak self] in
                self?.queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.poll()
                }
            }, done: { [weak self] object in
                self?.pollFailures = 0
                self?.handle(object)
            })
        }

        private func ready(_ object: [String: Any]) {
            let items = object["files"] as? [[String: Any]] ?? []
            if items.isEmpty || items.count > MokoSaveinator.maxFiles {
                self.fail("no_media")
                return
            }
            let prefix = "/api/v1/downloads/\(self.id)/files/"
            var plan: [PlannedFile] = []
            var texts = 0
            var total: Int64 = 0
            for item in items {
                let path = item["url"] as? String ?? ""
                let contentType = item["content_type"] as? String ?? ""
                let size = (item["size"] as? NSNumber)?.int64Value ?? 0
                let index = path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : ""
                guard !index.isEmpty, index.allSatisfy({ $0.isASCII && $0.isNumber }), let fileExtension = MokoSaveinator.fileExtension(forContentType: contentType) else {
                    self.fail("failed")
                    return
                }
                if size <= 0 || size > MokoSaveinator.maxFileSize {
                    self.fail("too_large")
                    return
                }
                if contentType == "text/plain" {
                    texts += 1
                }
                total += size
                plan.append(PlannedFile(path: path, contentType: contentType, fileExtension: fileExtension, size: size))
            }
            if texts > 1 {
                self.fail("failed")
                return
            }
            let directory = self.root.appendingPathComponent(self.id)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                self.fail("failed")
                return
            }
            self.directory = directory
            self.plan = plan
            self.totalBytes = max(total, 1)
            self.downloadNext()
        }

        private func downloadNext() {
            guard !self.finished else {
                return
            }
            let index = self.next
            self.next += 1
            guard index < self.plan.count, let directory = self.directory else {
                self.deliver()
                return
            }
            let file = self.plan[index]
            let destination = directory.appendingPathComponent("media_\(index).\(file.fileExtension)")
            self.request = self.transport.download(path: file.path, to: destination, progress: { [weak self] received in
                guard let self else {
                    return
                }
                self.queue.async {
                    guard !self.finished else {
                        return
                    }
                    let fraction = Double(self.completedBytes + min(received, file.size)) / Double(self.totalBytes)
                    self.subscriber.putNext(.progress(min(max(fraction, 0.0), 1.0)))
                }
            }, completion: { [weak self] status, contentType, received in
                guard let self else {
                    return
                }
                self.queue.async {
                    guard !self.finished else {
                        return
                    }
                    self.request = nil
                    if status != 200 {
                        self.fail(Job.httpError(status))
                    } else if received != file.size || contentType != file.contentType {
                        self.fail(received > file.size ? "too_large" : "failed")
                    } else {
                        if file.contentType == "text/plain" {
                            self.text = ((try? String(contentsOf: destination, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            try? FileManager.default.removeItem(at: destination)
                        } else {
                            self.files.append(MokoSaveinatorFile(url: destination, contentType: file.contentType))
                        }
                        self.completedBytes += file.size
                        self.downloadNext()
                    }
                }
            })
        }

        private func deliver() {
            guard let directory = self.directory else {
                self.fail("failed")
                return
            }
            if self.files.isEmpty && self.text.isEmpty {
                self.fail("no_media")
                return
            }
            self.finished = true
            self.deadline?.cancel()
            self.subscriber.putNext(.progress(1.0))
            self.subscriber.putNext(.finished(MokoSaveinatorResult(directory: directory, files: self.files, text: self.text)))
            self.subscriber.putCompletion()
        }
    }
}
