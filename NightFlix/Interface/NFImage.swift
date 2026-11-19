import ImageIO
import SwiftUI
import UIKit

/// Loads, decodes and caches artwork. Decoded images live in memory (so rails scroll
/// without flashing placeholders when cells are recycled) and the raw bytes go through
/// the shared URL cache on disk. Concurrent requests for the same URL share one load.
final class NFImagePipeline {
    static let shared = NFImagePipeline()

    private let memory = NSCache<NSURL, UIImage>()
    private let colors = NSCache<NSURL, UIColor>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let session: URLSession

    private init() {
        memory.totalCostLimit = 120 * 1024 * 1024
        memory.countLimit = 600

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 400 * 1024 * 1024,
            diskPath: "NightFlixArtworkCache"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 25
        configuration.httpMaximumConnectionsPerHost = 8
        session = URLSession(configuration: configuration)
    }

    func cachedImage(for url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cachedImage(for: url) {
            return cached
        }

        if let existing = inFlight[url] {
            return await existing.value
        }

        let session = session
        let task = Task<UIImage?, Never> {
            guard let (data, response) = try? await session.data(from: url),
                  (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true else {
                return nil
            }

            return await Task.detached(priority: .userInitiated) {
                NFImagePipeline.decode(data, maxPixelSize: 1600)
            }.value
        }

        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image {
            memory.setObject(image, forKey: url as NSURL, cost: image.nfMemoryCost)
        }

        return image
    }

    func prefetch(_ urls: [URL]) {
        for url in urls where cachedImage(for: url) == nil && inFlight[url] == nil {
            Task(priority: .utility) {
                _ = await image(for: url)
            }
        }
    }

    /// A deep, saturated tint sampled from the artwork, for ambient backgrounds.
    func ambientColor(for url: URL) async -> UIColor? {
        if let cached = colors.object(forKey: url as NSURL) {
            return cached
        }

        guard let image = await image(for: url) else { return nil }

        let color = await Task.detached(priority: .utility) {
            NFImagePipeline.ambientColor(of: image)
        }.value

        if let color {
            colors.setObject(color, forKey: url as NSURL)
        }

        return color
    }

    // MARK: - Decoding

    /// Decodes with ImageIO, downsampling large files so a poster never holds more
    /// pixels than the screen can show.
    nonisolated private static func decode(_ data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }

    /// Averages the most colourful pixels of a small thumbnail, then pushes the result to
    /// a dark, saturated tone that reads well behind white text.
    nonisolated private static func ambientColor(of image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }

        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drew: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }

            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }

        guard drew else { return nil }

        var samples: [(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, score: CGFloat)] = []
        samples.reserveCapacity(side * side)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let color = UIColor(
                red: CGFloat(pixels[index]) / 255,
                green: CGFloat(pixels[index + 1]) / 255,
                blue: CGFloat(pixels[index + 2]) / 255,
                alpha: 1
            )

            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

            // Favour vivid mid-tones; ignore near-black and blown-out pixels.
            let usable = brightness > 0.12 && brightness < 0.96
            let score = usable ? saturation * (1 - abs(brightness - 0.55)) : 0
            samples.append((hue, saturation, brightness, score))
        }

        let ranked = samples.sorted { $0.score > $1.score }
        let top = ranked.prefix(max(ranked.count / 5, 1)).filter { $0.score > 0 }
        guard !top.isEmpty else {
            return UIColor(white: 0.16, alpha: 1)
        }

        // Average hue on the colour wheel so reds near 0°/360° don't cancel out.
        var x: CGFloat = 0
        var y: CGFloat = 0
        var saturationSum: CGFloat = 0
        for sample in top {
            x += cos(sample.hue * 2 * .pi)
            y += sin(sample.hue * 2 * .pi)
            saturationSum += sample.saturation
        }

        var hue = atan2(y, x) / (2 * .pi)
        if hue < 0 { hue += 1 }

        let saturation = min(max(saturationSum / CGFloat(top.count) * 1.1, 0.35), 0.85)
        return UIColor(hue: hue, saturation: saturation, brightness: 0.42, alpha: 1)
    }
}

private extension UIImage {
    var nfMemoryCost: Int {
        guard let cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

// MARK: - View

/// Artwork view: fills its frame (the caller sizes it), fades the image in once
/// loaded, and shows a quiet placeholder until then.
struct NFImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var alignment: Alignment = .center
    var placeholder: Placeholder = .shimmer

    enum Placeholder {
        /// Animated skeleton while loading, flat grey when there's no artwork.
        case shimmer
        /// Flat grey only.
        case flat
        /// Nothing (for logos and overlays).
        case none
    }

    @State private var image: UIImage?
    @State private var didFail = false

    init(
        url: URL?,
        contentMode: ContentMode = .fill,
        alignment: Alignment = .center,
        placeholder: Placeholder = .shimmer
    ) {
        self.url = url
        self.contentMode = contentMode
        self.alignment = alignment
        self.placeholder = placeholder
        _image = State(initialValue: url.flatMap { NFImagePipeline.shared.cachedImage(for: $0) })
    }

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity.animation(.easeOut(duration: 0.22)))
                } else {
                    placeholderView
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    @ViewBuilder
    private var placeholderView: some View {
        switch placeholder {
        case .shimmer:
            if url == nil || didFail {
                NF.surfaceRaised
            } else {
                SkeletonView(cornerRadius: 0)
            }
        case .flat:
            NF.surfaceRaised
        case .none:
            Color.clear
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }

        if let cached = NFImagePipeline.shared.cachedImage(for: url) {
            image = cached
            return
        }

        image = nil
        didFail = false
        let loaded = await NFImagePipeline.shared.image(for: url)
        guard !Task.isCancelled else { return }

        if let loaded {
            withAnimation(.easeOut(duration: 0.22)) {
                image = loaded
            }
        } else {
            didFail = true
        }
    }
}
