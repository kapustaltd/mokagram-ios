import Foundation
import UIKit
import AVFoundation
import TelegramCore
import AccountContext
import MokoSaveinator

/// Turns downloaded files into media for the normal send path.
enum MokoSaveinatorMedia {
    enum Group {
        case visual
        case audio
        case document
    }

    struct Built {
        let media: EngineRawMedia
        let group: Group
    }

    static func randomId() -> Int64 {
        return Int64.random(in: Int64.min ... Int64.max)
    }

    /// Blocking: probes the file and writes a thumbnail. Call off the main thread.
    static func build(context: AccountContext, file: MokoSaveinatorFile) -> Built? {
        let size = (try? FileManager.default.attributesOfItem(atPath: file.url.path)[.size] as? NSNumber)?.int64Value ?? 0
        guard size > 0 else {
            return nil
        }
        switch file.contentType {
        case "image/jpeg", "image/png", "image/webp":
            if let photo = photo(context: context, url: file.url) {
                return Built(media: photo, group: .visual)
            }
            return document(file: file, size: size, extra: [])
        case "video/mp4", "video/quicktime":
            if let video = video(context: context, file: file, size: size) {
                return Built(media: video, group: .visual)
            }
            return document(file: file, size: size, extra: [])
        case "audio/mpeg", "audio/mp4", "audio/ogg", "audio/wav", "audio/flac":
            let seconds = CMTimeGetSeconds(AVURLAsset(url: file.url).duration)
            let duration = seconds.isFinite && seconds > 0.0 ? Int(seconds.rounded()) : 0
            return Built(media: makeFile(file: file, size: size, preview: [], attributes: [.Audio(isVoice: false, duration: duration, title: nil, performer: nil, waveform: nil), .FileName(fileName: file.url.lastPathComponent)]), group: .audio)
        default:
            return document(file: file, size: size, extra: [])
        }
    }

    private static func document(file: MokoSaveinatorFile, size: Int64, extra: [TelegramMediaFileAttribute]) -> Built {
        return Built(media: makeFile(file: file, size: size, preview: [], attributes: [.FileName(fileName: file.url.lastPathComponent)] + extra), group: .document)
    }

    private static func makeFile(file: MokoSaveinatorFile, size: Int64, preview: [TelegramMediaImageRepresentation], attributes: [TelegramMediaFileAttribute]) -> TelegramMediaFile {
        let id = randomId()
        return TelegramMediaFile(
            fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: id),
            partialReference: nil,
            resource: LocalFileReferenceMediaResource(localFilePath: file.url.path, randomId: id, isUniquelyReferencedTemporaryFile: true, size: size),
            previewRepresentations: preview,
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: file.contentType,
            size: size,
            attributes: attributes,
            alternativeRepresentations: []
        )
    }

    private static func jpeg(_ image: UIImage, maxSide: CGFloat, quality: CGFloat) -> (data: Data, size: CGSize)? {
        let source = image.size
        guard source.width > 0.0, source.height > 0.0 else {
            return nil
        }
        let scale = min(1.0, maxSide / max(source.width, source.height))
        let target = CGSize(width: max(1.0, (source.width * scale).rounded()), height: max(1.0, (source.height * scale).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let data = rendered.jpegData(compressionQuality: quality) else {
            return nil
        }
        return (data, target)
    }

    private static func storeRepresentation(context: AccountContext, data: Data, size: CGSize) -> TelegramMediaImageRepresentation {
        let resource = LocalFileMediaResource(fileId: randomId())
        context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: data, synchronous: true)
        return TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: Int32(size.width), height: Int32(size.height)), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
    }

    private static func photo(context: AccountContext, url: URL) -> TelegramMediaImage? {
        guard let image = UIImage(contentsOfFile: url.path), let prepared = jpeg(image, maxSide: 2560.0, quality: 0.9) else {
            return nil
        }
        let representation = storeRepresentation(context: context, data: prepared.data, size: prepared.size)
        return TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: randomId()), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
    }

    private static func video(context: AccountContext, file: MokoSaveinatorFile, size: Int64) -> TelegramMediaFile? {
        let asset = AVURLAsset(url: file.url)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0.0, let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        let dimensions = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        guard dimensions.width >= 1.0, dimensions.height >= 1.0 else {
            return nil
        }
        var preview: [TelegramMediaImageRepresentation] = []
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640.0, height: 640.0)
        if let cgImage = try? generator.copyCGImage(at: CMTime(seconds: min(1.0, seconds / 2.0), preferredTimescale: 600), actualTime: nil), let prepared = jpeg(UIImage(cgImage: cgImage), maxSide: 640.0, quality: 0.8) {
            preview.append(storeRepresentation(context: context, data: prepared.data, size: prepared.size))
        }
        let pixels = PixelDimensions(width: Int32(dimensions.width.rounded()), height: Int32(dimensions.height.rounded()))
        return makeFile(file: file, size: size, preview: preview, attributes: [
            .Video(duration: seconds, size: pixels, flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil),
            .FileName(fileName: file.url.lastPathComponent),
        ])
    }
}
