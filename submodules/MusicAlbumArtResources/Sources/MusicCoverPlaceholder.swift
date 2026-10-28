import Foundation
import UIKit

/// The one placeholder every music surface draws when a track has no cover at all (rows, compact
/// player, expanded player), so they cannot disagree. It is a gradient whose hue comes from the
/// track's title and artist, with a note glyph on top.
public enum MusicCoverPlaceholder {
    /// A hash that is stable between launches (`hashValue` is not).
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    public static func colors(seed: String) -> (UIColor, UIColor) {
        let hash = stableHash(seed)
        let hue = CGFloat(hash % 360) / 360.0
        let top = UIColor(hue: hue, saturation: 0.45, brightness: 0.78, alpha: 1.0)
        let bottom = UIColor(hue: (hue + 0.07).truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 0.45, alpha: 1.0)
        return (top, bottom)
    }

    private static func glyph(side: CGFloat) -> CGImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: .medium)
        guard let symbol = UIImage(systemName: "music.note", withConfiguration: configuration)?.withTintColor(UIColor(white: 1.0, alpha: 0.85), renderingMode: .alwaysOriginal) else {
            return nil
        }
        return UIGraphicsImageRenderer(size: symbol.size).image { _ in
            symbol.draw(at: .zero)
        }.cgImage
    }

    /// Draws the placeholder into `rect` of a context whose y axis points up (the flipped context of
    /// a `DrawingContext`, or `image(size:seed:)`'s).
    public static func draw(into context: CGContext, rect: CGRect, seed: String) {
        let (top, bottom) = self.colors(seed: seed)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0.0, 1.0]) {
            context.saveGState()
            context.clip(to: rect)
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
            context.restoreGState()
        }
        let side = floor(min(rect.width, rect.height) * 0.42)
        if side >= 6.0, let glyph = self.glyph(side: side) {
            let width = CGFloat(glyph.width) * side / CGFloat(max(glyph.height, 1))
            let glyphRect = CGRect(x: rect.midX - width / 2.0, y: rect.midY - side / 2.0, width: width, height: side)
            context.draw(glyph, in: glyphRect)
        }
    }

    /// The same placeholder as an image, for views that are not drawn through a `DrawingContext`.
    public static func image(size: CGSize, seed: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let context = renderer.cgContext
            // `draw` expects a y-up context: UIKit's is y-down, so flip it.
            context.translateBy(x: 0.0, y: size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            self.draw(into: context, rect: CGRect(origin: .zero, size: size), seed: seed)
        }
    }

    public static func seed(title: String, performer: String) -> String {
        return "\(performer)|\(title)"
    }
}
