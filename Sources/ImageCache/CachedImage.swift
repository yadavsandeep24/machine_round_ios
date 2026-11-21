import CoreGraphics
import SwiftUI

/// Drop-in for AsyncImage with caching, dedupe and downsampling.
/// `.task(id: url)` cancels the old load when a reused row gets a new URL,
/// and the image is reset first, so a recycled row never flashes the previous
/// row's picture.
public struct CachedImage: View {
    let url: URL?
    let pipeline: ImagePipeline
    let pointSize: CGFloat
    @Environment(\.displayScale) private var scale
    @State private var image: CGImage?
    @State private var failed = false

    public init(url: URL?, pipeline: ImagePipeline, pointSize: CGFloat) {
        self.url = url
        self.pipeline = pipeline
        self.pointSize = pointSize
    }

    public var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: scale).resizable().scaledToFill()
            } else if failed {
                Image(systemName: "photo").foregroundStyle(.secondary)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: pointSize, height: pointSize)
        .clipped()
        .task(id: url) {
            image = nil
            failed = false
            guard let url else { failed = true; return }
            do {
                image = try await pipeline.image(for: url, maxPixelSize: Int(pointSize * scale))
            } catch is CancellationError {
            } catch {
                failed = true
            }
        }
    }
}
