import CoreGraphics
import Foundation
import ImageIO

/// Decodes straight to a thumbnail with ImageIO. A 4000×3000 photo decoded at
/// full size costs 4000 * 3000 * 4 bytes = 48 MB of RAM, whatever its file size;
/// decoding at display size is the biggest memory win in image lists.
public enum Downsampler {
    public static func image(from data: Data, maxPixelSize: Int?) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary // don't decode yet
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        guard let maxPixelSize else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true, // decode now, off the main thread
            kCGImageSourceCreateThumbnailWithTransform: true, // respect EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as [CFString: Any] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
