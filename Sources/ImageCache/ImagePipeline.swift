import CoreGraphics
import Core
import Foundation

public protocol ImageDataLoader: Sendable {
    func data(for url: URL) async throws -> Data
}

public struct URLSessionImageLoader: ImageDataLoader {
    public init() {}
    public func data(for url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, let error = AppError.fromStatus(http.statusCode) { throw error }
        return data
    }
}

public enum ImagePipelineError: Error, Equatable { case undecodable }

/// Loads, downsamples and caches images.
///
/// The interview points, in order:
/// 1. **Actor** so the caches are never accessed concurrently.
/// 2. **Reentrancy:** an actor is NOT locked across `await`. Two calls for the
///    same URL can both miss the cache before either finishes, so the
///    in-flight `Task` is stored and shared: one download per URL.
/// 3. **Failures are not cached:** the in-flight entry is removed on error.
/// 4. **Cancellation semantics:** one caller cancelling (its cell scrolled
///    away) must not cancel the download for the others; when the LAST waiter
///    cancels, the download is cancelled.
/// 5. **Memory:** an LRU limit on decoded images, decoded at display size.
public actor ImagePipeline {
    private struct Key: Hashable { let url: URL; let maxPixelSize: Int? }
    private struct InFlight { let task: Task<CGImage, any Error>; var waiters: Set<UUID> }

    private var memory: LRUCache<Key, CGImage>
    private var inFlight: [Key: InFlight] = [:]
    private let loader: any ImageDataLoader

    public init(loader: any ImageDataLoader = URLSessionImageLoader(), countLimit: Int = 100) {
        self.loader = loader
        self.memory = LRUCache(countLimit: countLimit)
    }

    public func image(for url: URL, maxPixelSize: Int? = nil) async throws -> CGImage {
        let key = Key(url: url, maxPixelSize: maxPixelSize)
        if let cached = memory.value(for: key) { return cached }

        let waiter = UUID()
        let task: Task<CGImage, any Error>
        if var entry = inFlight[key] {
            entry.waiters.insert(waiter) // join the download already running
            inFlight[key] = entry
            task = entry.task
        } else {
            let loader = self.loader
            task = Task<CGImage, any Error> {
                let data = try await loader.data(for: url)
                try Task.checkCancellation()
                guard let image = Downsampler.image(from: data, maxPixelSize: maxPixelSize) else {
                    throw ImagePipelineError.undecodable
                }
                return image
            }
            inFlight[key] = InFlight(task: task, waiters: [waiter])
        }

        do {
            let image = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                Task { await self.leave(key, waiter, cancelled: true) }
            }
            memory.insert(image, for: key)
            leave(key, waiter, cancelled: false)
            try Task.checkCancellation() // this caller left; others still got the image
            return image
        } catch {
            // Failures are never cached: the next request starts a fresh download.
            if inFlight[key]?.task == task, !(error is CancellationError) { inFlight[key] = nil }
            leave(key, waiter, cancelled: false)
            throw error
        }
    }

    /// Idempotent: called once when the caller finishes and maybe once more
    /// from its cancellation handler.
    private func leave(_ key: Key, _ waiter: UUID, cancelled: Bool) {
        guard var entry = inFlight[key], entry.waiters.remove(waiter) != nil else { return }
        if entry.waiters.isEmpty {
            if cancelled { entry.task.cancel() } // the last interested caller left
            inFlight[key] = nil
        } else {
            inFlight[key] = entry
        }
    }

    public func cachedCount() -> Int { memory.count }
    public func removeAll() { memory.removeAll() }
}
