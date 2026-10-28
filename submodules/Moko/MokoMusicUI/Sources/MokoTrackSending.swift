import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import MokoMusic

/// Sending a SoundCloud track as an audio file (Desktop: "Переслать", "Добавить в профиль").
enum MokoTrackSending {
    enum SendError {
        case download(MokoMusicError)
        case notDelivered
        case profile
    }

    /// A fresh copy of the downloaded track with its own id and the cover as the thumbnail, so the
    /// recipient sees title, artist and artwork.
    private static func sendableFile(context: AccountContext, track: MokoMusicTrack, url: URL) -> Signal<TelegramMediaFile, NoError> {
        let cover: Signal<Data?, NoError>
        if let artwork = URL(string: track.largeArtworkUrl), !track.largeArtworkUrl.isEmpty {
            cover = Signal { subscriber in
                let task = URLSession.shared.dataTask(with: artwork, completionHandler: { data, _, _ in
                    subscriber.putNext(data)
                    subscriber.putCompletion()
                })
                task.resume()
                return ActionDisposable {
                    task.cancel()
                }
            }
        } else {
            cover = .single(nil)
        }
        return cover
        |> map { data -> TelegramMediaFile in
            let fileId = Int64.random(in: Int64.min ... Int64.max)
            let kind = track.matchingFile(url)
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("moko-send-\(fileId).\(kind.fileExtension)")
            try? FileManager.default.copyItem(at: url, to: copy)
            var previews: [TelegramMediaImageRepresentation] = []
            if let data, let image = UIImage(data: data) {
                let size = CGSize(width: 320.0, height: 320.0)
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1.0
                let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                if let jpeg = thumbnail.jpegData(compressionQuality: 0.8) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: jpeg, synchronous: true)
                    previews.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 320, height: 320), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                }
            }
            let size = (try? FileManager.default.attributesOfItem(atPath: copy.path)[.size] as? NSNumber)?.int64Value
            return TelegramMediaFile(
                fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: fileId),
                partialReference: nil,
                resource: LocalFileReferenceMediaResource(localFilePath: copy.path, randomId: fileId, isUniquelyReferencedTemporaryFile: true, size: size),
                previewRepresentations: previews,
                videoThumbnails: [],
                immediateThumbnailData: nil,
                mimeType: kind.mimeType,
                size: size,
                attributes: [
                    .Audio(isVoice: false, duration: track.durationMs / 1000, title: track.title, performer: track.artist, waveform: nil),
                    .FileName(fileName: "\(track.artist) - \(track.title).\(kind.fileExtension)"),
                ],
                alternativeRepresentations: []
            )
        }
    }

    /// Downloads if needed and sends to `peerId`; completes with the local message id.
    static func send(context: AccountContext, track: MokoMusicTrack, peerId: EnginePeer.Id, threadId: Int64?, correlationId: Int64? = nil) -> Signal<EngineMessage.Id?, SendError> {
        return MokoMusicContext.shared.downloader.download(track)
        |> mapError { SendError.download($0) }
        |> mapToSignal { url -> Signal<EngineMessage.Id?, SendError> in
            return sendableFile(context: context, track: track, url: url)
            |> castError(SendError.self)
            |> mapToSignal { file -> Signal<EngineMessage.Id?, SendError> in
                return enqueueMessages(account: context.account, peerId: peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: threadId, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: correlationId, bubbleUpEmojiOrStickersets: [])])
                |> castError(SendError.self)
                |> map { ids in
                    return ids.first ?? nil
                }
            }
        }
    }

    /// Profile music needs a file Telegram already has: send to Saved Messages, wait for the server
    /// copy, then add that message's file to the profile.
    static func addToProfile(context: AccountContext, track: MokoMusicTrack) -> Signal<Never, SendError> {
        let savedPeerId = context.account.peerId
        let correlationId = Int64.random(in: 1 ... Int64.max)
        let manager = context.account.pendingMessageManager!
        let delivered: Signal<EngineMessage.Id, SendError> = manager.deliveredMessageEvents(peerId: savedPeerId)
        |> mapToSignal { events -> Signal<EngineMessage.Id, NoError> in
            guard let sentId = manager.synchronouslyLookupCorrelationId(correlationId: correlationId), events.contains(where: { $0.id == sentId }) else {
                return .complete()
            }
            return .single(sentId)
        }
        |> take(1)
        |> castError(SendError.self)
        |> timeout(120.0, queue: .mainQueue(), alternate: .fail(.notDelivered))
        return send(context: context, track: track, peerId: savedPeerId, threadId: nil, correlationId: correlationId)
        |> ignoreValues
        |> then(delivered
        |> mapToSignal { messageId -> Signal<Never, SendError> in
            return context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> castError(SendError.self)
            |> mapToSignal { message -> Signal<Never, SendError> in
                guard let message, let file = message.media.compactMap({ $0 as? TelegramMediaFile }).first else {
                    return .fail(.profile)
                }
                return context.engine.peers.addSavedMusic(file: .message(message: MessageReference(message._asMessage()), media: file))
                |> mapError { _ in SendError.profile }
            }
        })
    }
}
