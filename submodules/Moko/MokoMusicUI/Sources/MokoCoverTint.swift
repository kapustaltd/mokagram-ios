import Foundation
import UIKit

/// The background colour of the expanded player, sampled from the cover.
public enum MokoCoverTint {
    public static let fallback = UIColor(red: 0.18, green: 0.2, blue: 0.24, alpha: 1.0)

    /// Averages the cover over an 8x8 grid and tones it so white text stays readable on it.
    public static func color(for image: UIImage) -> UIColor {
        guard let cgImage = image.cgImage else {
            return fallback
        }
        let side = 8
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                return false
            }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else {
            return fallback
        }
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        for index in 0 ..< side * side {
            red += Double(pixels[index * 4])
            green += Double(pixels[index * 4 + 1])
            blue += Double(pixels[index * 4 + 2])
        }
        let count = Double(side * side) * 255.0
        let average = UIColor(red: CGFloat(red / count), green: CGFloat(green / count), blue: CGFloat(blue / count), alpha: 1.0)
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        guard average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return fallback
        }
        return UIColor(hue: hue, saturation: min(max(saturation, 0.2), 0.7), brightness: min(max(brightness, 0.22), 0.46), alpha: 1.0)
    }

    /// The darker end of the background gradient.
    public static func bottomColor(for tint: UIColor) -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if tint.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness * 0.35, alpha: 1.0)
        }
        return UIColor(white: 0.06, alpha: 1.0)
    }
}
