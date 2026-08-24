import AppKit
import SwiftUI

final class PaletteAssetStore {
    static let shared = PaletteAssetStore()

    private let images: NSCache<NSURL, NSImage> = {
        let cache = NSCache<NSURL, NSImage>()
        cache.countLimit = 64
        return cache
    }()

    func image(for descriptor: PaletteAssetDescriptor) -> NSImage? {
        let key = descriptor.url as NSURL
        if let image = images.object(forKey: key) { return image }
        guard let image = NSImage(contentsOf: descriptor.url) else { return nil }
        images.setObject(image, forKey: key)
        return image
    }
}

struct PaletteRingArtwork: View {
    let descriptor: PaletteAssetDescriptor
    let progress: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        if let image = PaletteAssetStore.shared.image(for: descriptor) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .mask(
                    Circle()
                        .inset(by: lineWidth / 2)
                        .trim(from: 0, to: progress)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

struct PaletteRingCap: View {
    let descriptor: PaletteAssetDescriptor
    let progress: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { proxy in
            if let image = PaletteAssetStore.shared.image(for: descriptor), progress > 0.001 {
                let radius = (min(proxy.size.width, proxy.size.height) - lineWidth) / 2
                let angle = Double(progress) * 2 * Double.pi - Double.pi / 2
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: lineWidth + 2, height: lineWidth + 2)
                    .position(
                        x: proxy.size.width / 2 + radius * cos(angle),
                        y: proxy.size.height / 2 + radius * sin(angle)
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct PaletteAssetFill: View {
    let descriptor: PaletteAssetDescriptor

    var body: some View {
        if let image = PaletteAssetStore.shared.image(for: descriptor) {
            switch descriptor.renderMode {
            case .tileX:
                PaletteTiledAssetFill(image: image, axis: .horizontal)
            case .tileY:
                PaletteTiledAssetFill(image: image, axis: .vertical)
            case .fullRing, .fixed:
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            }
        }
    }
}

private struct PaletteTiledAssetFill: View {
    enum Axis {
        case horizontal
        case vertical
    }

    let image: NSImage
    let axis: Axis

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard image.size.width > 0, image.size.height > 0, size.width > 0, size.height > 0 else { return }
            let resolved = context.resolve(Image(nsImage: image))

            switch axis {
            case .horizontal:
                // Scale the complete SVG strip to the target height first, then
                // repeat it. SwiftUI's .tile keeps the 32pt source height and a
                // 10pt progress bar therefore exposes only a cropped edge.
                let tileWidth = max(1, size.height * image.size.width / image.size.height)
                var x: CGFloat = 0
                while x < size.width {
                    context.draw(resolved, in: CGRect(x: x, y: 0, width: tileWidth, height: size.height))
                    x += tileWidth
                }
            case .vertical:
                let tileHeight = max(1, size.width * image.size.height / image.size.width)
                var y: CGFloat = 0
                while y < size.height {
                    context.draw(resolved, in: CGRect(x: 0, y: y, width: size.width, height: tileHeight))
                    y += tileHeight
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
