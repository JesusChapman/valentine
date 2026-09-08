import AppKit

extension NSImage {
    /// Samples a small version of the artwork to find its most frequent vivid color.
    /// Ignoring near-black, near-white, and gray pixels prevents borders or text from
    /// becoming the accent color.
    func dominantArtworkColor(sampleDimension: Int = 48) -> NSColor? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = sampleDimension
        let height = sampleDimension
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        func colorBin(at pixelIndex: Int, includingNeutralColors: Bool) -> Int? {
            let red = CGFloat(pixels[pixelIndex]) / 255
            let green = CGFloat(pixels[pixelIndex + 1]) / 255
            let blue = CGFloat(pixels[pixelIndex + 2]) / 255
            let alpha = pixels[pixelIndex + 3]
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let saturation = maximum == 0 ? 0 : (maximum - minimum) / maximum

            guard alpha > 200 else { return nil }
            guard includingNeutralColors || (saturation > 0.18 && maximum > 0.12 && maximum < 0.95) else {
                return nil
            }

            let redBin = Int(red * 10)
            let greenBin = Int(green * 10)
            let blueBin = Int(blue * 10)
            return (redBin << 16) | (greenBin << 8) | blueBin
        }

        func dominantBin(includingNeutralColors: Bool) -> Int? {
            var bins: [Int: Int] = [:]
            for pixelIndex in stride(from: 0, to: pixels.count, by: 4) {
                if let bin = colorBin(at: pixelIndex, includingNeutralColors: includingNeutralColors) {
                    bins[bin, default: 0] += 1
                }
            }
            return bins.max(by: { $0.value < $1.value })?.key
        }

        guard let selectedBin = dominantBin(includingNeutralColors: false)
                ?? dominantBin(includingNeutralColors: true) else {
            return nil
        }

        var totalRed = 0
        var totalGreen = 0
        var totalBlue = 0
        var count = 0
        for pixelIndex in stride(from: 0, to: pixels.count, by: 4) {
            guard colorBin(at: pixelIndex, includingNeutralColors: true) == selectedBin else { continue }
            totalRed += Int(pixels[pixelIndex])
            totalGreen += Int(pixels[pixelIndex + 1])
            totalBlue += Int(pixels[pixelIndex + 2])
            count += 1
        }

        guard count > 0 else { return nil }
        return NSColor(
            red: CGFloat(totalRed) / CGFloat(count * 255),
            green: CGFloat(totalGreen) / CGFloat(count * 255),
            blue: CGFloat(totalBlue) / CGFloat(count * 255),
            alpha: 1
        )
    }
}
