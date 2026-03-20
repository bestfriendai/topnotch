import AppKit
import Foundation

enum ArtworkColorExtractor {
    // Cache: image hash -> vibrant color
    private static var cache: [Int: NSColor] = [:]

    static func extract(from image: NSImage) -> NSColor? {
        let hash = Int(bitPattern: ObjectIdentifier(image))
        if let cached = cache[hash] { return cached }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        // Resize to 40x40 for performance
        let size = CGSize(width: 40, height: 40)
        let ctx = CGContext(
            data: nil, width: 40, height: 40,
            bitsPerComponent: 8, bytesPerRow: 40 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        guard let data = ctx?.data else { return nil }

        let ptr = data.bindMemory(to: UInt8.self, capacity: 40 * 40 * 4)
        var bestColor: NSColor? = nil
        var bestScore: Double = 0

        // Sample every 4th pixel (400 total, 100 sampled)
        for y in stride(from: 0, to: 40, by: 2) {
            for x in stride(from: 0, to: 40, by: 2) {
                let i = (y * 40 + x) * 4
                let r = Double(ptr[i]) / 255.0
                let g = Double(ptr[i+1]) / 255.0
                let b = Double(ptr[i+2]) / 255.0
                let a = Double(ptr[i+3]) / 255.0
                guard a > 0.5 else { continue }

                // Convert to HSB
                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let brightness = maxC
                let saturation = maxC > 0 ? (maxC - minC) / maxC : 0

                // Skip near-black, near-white, and low-saturation colors
                guard saturation > 0.25, brightness > 0.15, brightness < 0.95 else { continue }

                // Score: prefer high saturation + mid brightness
                let score = saturation * 0.7 + (1.0 - abs(brightness - 0.55)) * 0.3
                if score > bestScore {
                    bestScore = score
                    bestColor = NSColor(red: r, green: g, blue: b, alpha: 1.0)
                }
            }
        }

        // Fallback: if no vibrant color found, return dominant
        let result = bestColor ?? NSColor(red: 0.12, green: 0.84, blue: 0.38, alpha: 1.0)
        if cache.count > 30 { cache.removeAll() }
        cache[hash] = result
        return result
    }
}
