import Foundation
import UIKit
import TelegramCore
import SwiftSignalKit
import UrlEscaping
import MokoCore

public struct ExternalMusicAlbumArtResourceId {
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(title: String, performer: String, isThumbnail: Bool) {
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public var uniqueId: String {
        return "ext-album-art-\(self.isThumbnail ? "thumb" : "full")-\(self.title.replacingOccurrences(of: "/", with: "_"))-\(self.performer.replacingOccurrences(of: "/", with: "_"))"
    }
    
    public var hashValue: Int {
        return self.title.hashValue &* 31 &+ self.performer.hashValue
    }
}

public class ExternalMusicAlbumArtResource: Equatable {
    public let file: FileMediaReference?
    public let title: String
    public let performer: String
    public let isThumbnail: Bool
    
    public init(file: FileMediaReference?, title: String, performer: String, isThumbnail: Bool) {
        self.file = file
        self.title = title
        self.performer = performer
        self.isThumbnail = isThumbnail
    }
    
    public var id: EngineMediaResource.Id {
        return EngineMediaResource.Id(ExternalMusicAlbumArtResourceId(title: self.title, performer: self.performer, isThumbnail: self.isThumbnail).uniqueId)
    }

    public static func ==(lhs: ExternalMusicAlbumArtResource, rhs: ExternalMusicAlbumArtResource) -> Bool {
        if lhs.file?.media.fileId != rhs.file?.media.fileId {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.performer != rhs.performer {
            return false
        }
        if lhs.isThumbnail != rhs.isThumbnail {
            return false
        }
        return true
    }
}

public func fetchExternalMusicAlbumArtResource(engine: TelegramEngine, file: FileMediaReference?, resource: ExternalMusicAlbumArtResource) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    // mokaGram: a SoundCloud track carries its own cover; Telegram's lookup by title would guess.
    if let fileId = (file ?? resource.file)?.media.fileId.id, let url = MokoArtworkRegistry.url(fileId: fileId) {
        return Signal { subscriber in
            let task = URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                guard let data, !data.isEmpty else {
                    subscriber.putError(.generic)
                    return
                }
                subscriber.putNext(.dataPart(resourceOffset: 0, data: data, range: 0 ..< Int64(data.count), complete: true))
                subscriber.putCompletion()
            })
            task.resume()
            return ActionDisposable {
                task.cancel()
            }
        }
    }
    return engine.resources.fetchAlbumCover(file: file, title: resource.title, performer: resource.performer, isThumbnail: resource.isThumbnail)
}
