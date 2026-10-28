import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import UndoUI
import MokoCore
import MokoSaveinator
import MokoSettingsUI

/// Where and how the downloaded media goes: the options active when the user pressed send.
public struct MokoSaveinatorDestination {
    public var peerId: EnginePeer.Id
    public var threadId: Int64?
    public var replySubject: EngineMessageReplySubject?
    public var silent: Bool?
    public var scheduleTime: Int32?
    public var repeatPeriod: Int32?

    public init(peerId: EnginePeer.Id, threadId: Int64?, replySubject: EngineMessageReplySubject?, silent: Bool?, scheduleTime: Int32?, repeatPeriod: Int32?) {
        self.peerId = peerId
        self.threadId = threadId
        self.replySubject = replySubject
        self.silent = silent
        self.scheduleTime = scheduleTime
        self.repeatPeriod = repeatPeriod
    }
}

/// One link download with its progress toast. Main thread only.
public enum MokoSaveinatorTransfer {
    private static var active: [String: Disposable] = [:]
    private static var didCleanup = false
    private static let maxFileSize: Int64 = 2000 * 1024 * 1024
    private static let maxPremiumFileSize: Int64 = 4000 * 1024 * 1024

    /// - `send` hands the messages to the chat that started the download (so its own send options
    ///   apply); return false when that chat is gone to have them sent directly.
    /// - `failed` is called when nothing was sent (error or cancel), to put the text back.
    public static func start(context: AccountContext, link: String, choice: MokoSaveinatorChoice, destination: MokoSaveinatorDestination, send: @escaping ([EnqueueMessage]) -> Bool, failed: @escaping () -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        if active[link] != nil {
            toast(context, strings.moko("Эта ссылка уже скачивается."))
            failed()
            return
        }
        if !didCleanup {
            didCleanup = true
            MokoSaveinator.cleanupRoot()
        }
        let configuration = MokoSaveinatorConfiguration.current()
        let transport = configuration.map { MokoSaveinatorURLSessionTransport(configuration: $0) }

        let host = MokoSaveinatorLink.host(of: link)
        let state = ProgressState()
        var overlay: UndoOverlayController?
        let finish: () -> Void = {
            active[link]?.dispose()
            active[link] = nil
            state.timer?.invalidate()
            state.timer = nil
            overlay?.dismiss()
            overlay = nil
        }
        let makeContent: () -> UndoOverlayContent = {
            return .progress(progress: CGFloat(state.fraction), title: strings.moko("Скачиваю"), text: host, undoText: strings.moko("Отмена"))
        }
        let controller = UndoOverlayController(presentationData: presentationData, content: makeContent(), elevatedLayout: false, action: { action in
            if action == .undo {
                finish()
                failed()
            }
            return false
        })
        overlay = controller
        context.sharedContext.mainWindow?.present(controller, on: .root, blockInteraction: false, completion: {})
        // Keeps the toast up while the service is preparing the media and reports nothing.
        state.timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: {
            overlay?.content = makeContent()
        }, queue: Queue.mainQueue())
        state.timer?.start()

        let signal = MokoSaveinator.download(link: link, choice: choice, transport: transport)
        |> deliverOnMainQueue
        active[link] = signal.start(next: { event in
            switch event {
            case let .progress(value):
                state.fraction = value
                overlay?.content = makeContent()
            case let .finished(result):
                state.timer?.invalidate()
                state.timer = nil
                overlay?.content = .progress(progress: 1.0, title: strings.moko("Готовлю к отправке…"), text: host, undoText: nil)
                prepare(context: context, result: result, destination: destination, strings: strings, send: send, completion: { success in
                    finish()
                    if !success {
                        failed()
                    }
                })
            }
        }, error: { error in
            finish()
            toast(context, strings.moko(MokoSaveinator.errorText(code: error.code)))
            failed()
        })
    }

    private final class ProgressState {
        var fraction: Double = 0.0
        var timer: SwiftSignalKit.Timer?
    }

    private static func prepare(context: AccountContext, result: MokoSaveinatorResult, destination: MokoSaveinatorDestination, strings: PresentationStrings, send: @escaping ([EnqueueMessage]) -> Bool, completion: @escaping (Bool) -> Void) {
        let limit = context.isPremium ? maxPremiumFileSize : maxFileSize
        DispatchQueue.global(qos: .userInitiated).async {
            var built: [MokoSaveinatorMedia.Built] = []
            var tooLarge = false
            for file in result.files {
                let size = (try? FileManager.default.attributesOfItem(atPath: file.url.path)[.size] as? NSNumber)?.int64Value ?? 0
                if size > limit {
                    tooLarge = true
                    break
                }
                if let item = MokoSaveinatorMedia.build(context: context, file: file) {
                    built.append(item)
                }
            }
            DispatchQueue.main.async {
                if tooLarge {
                    try? FileManager.default.removeItem(at: result.directory)
                    toast(context, strings.moko("Файл слишком большой для отправки в Telegram."))
                    completion(false)
                    return
                }
                let messages = makeMessages(built: built, text: result.text, destination: destination)
                if messages.isEmpty {
                    try? FileManager.default.removeItem(at: result.directory)
                    toast(context, strings.moko("Не удалось подготовить файл к отправке."))
                    completion(false)
                    return
                }
                if !send(messages) {
                    sendDirectly(context: context, messages: messages, destination: destination)
                }
                completion(true)
            }
        }
    }

    static func makeMessages(built: [MokoSaveinatorMedia.Built], text: String, destination: MokoSaveinatorDestination) -> [EnqueueMessage] {
        var messages: [EnqueueMessage] = []
        for group in [MokoSaveinatorMedia.Group.visual, .audio, .document] {
            let items = built.filter { $0.group == group }
            let key: Int64? = items.count > 1 ? Int64.random(in: 1 ... Int64.max) : nil
            for item in items {
                messages.append(.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: item.media), threadId: destination.threadId, replyToMessageId: destination.replySubject, replyToStoryId: nil, localGroupingKey: key, correlationId: nil, bubbleUpEmojiOrStickersets: []))
            }
        }
        if !text.isEmpty {
            messages.append(.message(text: text, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: destination.threadId, replyToMessageId: destination.replySubject, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))
        }
        return messages
    }

    /// Fallback when the chat that started the download is gone: the same send options as attributes.
    private static func sendDirectly(context: AccountContext, messages: [EnqueueMessage], destination: MokoSaveinatorDestination) {
        let messages = messages.map { message in
            return message.withUpdatedAttributes { attributes in
                var attributes = attributes
                if destination.silent == true {
                    attributes.append(NotificationInfoMessageAttribute(flags: .muted))
                }
                if let scheduleTime = destination.scheduleTime {
                    attributes.append(OutgoingScheduleInfoMessageAttribute(scheduleTime: scheduleTime, repeatPeriod: destination.repeatPeriod))
                }
                return attributes
            }
        }
        let _ = enqueueMessages(account: context.account, peerId: destination.peerId, messages: messages).startStandalone()
    }

    private static func toast(_ context: AccountContext, _ text: String) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.mainWindow?.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), on: .root, blockInteraction: false, completion: {})
    }
}
