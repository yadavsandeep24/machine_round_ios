import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import ImageCache

func pngData(width: Int, height: Int) -> Data {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    return data as Data
}

/// Counts calls; optional delay; observes cancellation of the underlying download.
final class FakeLoader: ImageDataLoader, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [URL] = []
    private var _cancelled = 0
    var delay: Duration = .zero
    var failNext = false
    var calls: [URL] { lock.withLock { _calls } }
    var cancelledDownloads: Int { lock.withLock { _cancelled } }

    func data(for url: URL) async throws -> Data {
        let fail = lock.withLock { () -> Bool in
            _calls.append(url)
            defer { failNext = false }
            return failNext
        }
        do {
            if delay > .zero { try await Task.sleep(for: delay) }
        } catch {
            lock.withLock { _cancelled += 1 }
            throw error
        }
        if fail { throw URLError(.badServerResponse) }
        return pngData(width: 400, height: 300)
    }
}

let url = URL(string: "https://img.test/1.png")!

@Suite struct ImagePipelineTests {
    @Test func tenConcurrentRequestsForOneURLDownloadOnce() async throws {
        let loader = FakeLoader()
        loader.delay = .milliseconds(50)
        let pipeline = ImagePipeline(loader: loader)
        try await withThrowingTaskGroup(of: CGImage.self) { group in
            for _ in 0..<10 { group.addTask { try await pipeline.image(for: url) } }
            for try await _ in group {}
        }
        #expect(loader.calls.count == 1)
    }

    @Test func secondRequestIsServedFromMemory() async throws {
        let loader = FakeLoader()
        let pipeline = ImagePipeline(loader: loader)
        _ = try await pipeline.image(for: url)
        _ = try await pipeline.image(for: url)
        #expect(loader.calls.count == 1)
    }

    @Test func failuresAreNotCached() async throws {
        let loader = FakeLoader()
        loader.failNext = true
        let pipeline = ImagePipeline(loader: loader)
        await #expect(throws: URLError.self) { try await pipeline.image(for: url) }
        _ = try await pipeline.image(for: url)
        #expect(loader.calls.count == 2)
    }

    @Test func oneCallerCancellingDoesNotCancelTheOthers() async throws {
        let loader = FakeLoader()
        loader.delay = .milliseconds(100)
        let pipeline = ImagePipeline(loader: loader)
        let leaving = Task { try await pipeline.image(for: url) }
        let staying = Task { try await pipeline.image(for: url) }
        try await Task.sleep(for: .milliseconds(20))
        leaving.cancel() // its cell scrolled off screen
        let image = try await staying.value
        #expect(image.width == 400)
        #expect(loader.cancelledDownloads == 0)
        #expect(loader.calls.count == 1)
    }

    @Test func lastCallerCancellingCancelsTheDownload() async throws {
        let loader = FakeLoader()
        loader.delay = .milliseconds(300)
        let pipeline = ImagePipeline(loader: loader)
        let only = Task { try await pipeline.image(for: url) }
        try await Task.sleep(for: .milliseconds(20))
        only.cancel()
        _ = try? await only.value
        try await Task.sleep(for: .milliseconds(50))
        #expect(loader.cancelledDownloads == 1)
    }

    @Test func memoryCacheEvictsLeastRecentlyUsed() async throws {
        let pipeline = ImagePipeline(loader: FakeLoader(), countLimit: 2)
        for i in 1...3 { _ = try await pipeline.image(for: URL(string: "https://img.test/\(i).png")!) }
        #expect(await pipeline.cachedCount() == 2)
    }

    @Test func downsamplesToTheRequestedSize() throws {
        let image = try #require(Downsampler.image(from: pngData(width: 1000, height: 500), maxPixelSize: 100))
        #expect(max(image.width, image.height) == 100)
        #expect(image.width == 100 && image.height == 50)
    }
}
