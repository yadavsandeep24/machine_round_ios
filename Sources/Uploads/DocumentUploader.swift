/// Uploads KYC documents with a cap on concurrent requests.
public struct DocumentUploader: Sendable {
    /// How the permit is given back. Both are correct; `.asyncDefer` is the Swift 6.4 way.
    public enum ReleaseStrategy: String, Sendable, CaseIterable {
        case asyncDefer
        case manualRelease
    }

    public let limiter: AsyncSemaphore
    private let transport: any UploadTransport
    private let strategy: ReleaseStrategy

    public init(maxConcurrent: Int = 2, transport: any UploadTransport, strategy: ReleaseStrategy = .asyncDefer) {
        self.limiter = AsyncSemaphore(permits: maxConcurrent)
        self.transport = transport
        self.strategy = strategy
    }

    public func upload(_ document: Document) async throws -> UploadReceipt {
        switch strategy {
        case .asyncDefer: try await uploadWithAsyncDefer(document)
        case .manualRelease: try await uploadWithManualRelease(document)
        }
    }

    /// AFTER (Swift 6.4, SE-0493): `await` inside `defer`.
    /// The permit is returned on every exit: success, thrown error, cancellation.
    /// The defer body finishes before the function returns, so callers never see a leaked permit.
    private func uploadWithAsyncDefer(_ document: Document) async throws -> UploadReceipt {
        await limiter.acquire()
        defer { await limiter.release() }

        try Task.checkCancellation() // we may have waited a long time for a permit
        return try await transport.send(document)
    }

    /// BEFORE (Swift 6.3 and earlier): `defer` could not `await`, so every exit path
    /// releases by hand. Easy to break when someone adds an early `return` or a new `throw`.
    private func uploadWithManualRelease(_ document: Document) async throws -> UploadReceipt {
        await limiter.acquire()
        do {
            try Task.checkCancellation()
            let receipt = try await transport.send(document)
            await limiter.release()
            return receipt
        } catch {
            await limiter.release()
            throw error
        }
        // The other old workaround, `defer { Task { await limiter.release() } }`, compiles but
        // releases *later*, on another task: the function returns while the permit is still held.
    }
}
