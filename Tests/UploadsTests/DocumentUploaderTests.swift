import Foundation
import Testing
@testable import Uploads

/// Fake network: records peak concurrency, can fail by name, can wait for a signal.
actor RecordingTransport: UploadTransport {
    private(set) var inFlight = 0
    private(set) var peak = 0
    private(set) var sent: [String] = []
    let delay: Duration
    let failing: Set<String>

    init(delay: Duration = .milliseconds(20), failing: Set<String> = []) {
        self.delay = delay
        self.failing = failing
    }

    func send(_ document: Document) async throws -> UploadReceipt {
        inFlight += 1
        peak = max(peak, inFlight)
        defer { inFlight -= 1 }
        sent.append(document.id)
        try await Task.sleep(for: delay)
        if failing.contains(document.id) { throw UploadError.rejected(reason: "bad \(document.id)") }
        return UploadReceipt(documentID: document.id, remoteURL: URL(string: "https://x.test/\(document.id)")!)
    }
}

func docs(_ count: Int) -> [Document] {
    (1...count).map { Document(id: "d\($0)", name: "Doc \($0)", sizeKB: 1) }
}

/// The same behaviour spec runs against the Swift 6.4 `defer { await ... }` version
/// and the old manual-release version.
@Suite struct DocumentUploaderTests {
    @Test(arguments: DocumentUploader.ReleaseStrategy.allCases)
    func neverExceedsTheConcurrencyCap(strategy: DocumentUploader.ReleaseStrategy) async throws {
        let transport = RecordingTransport()
        let uploader = DocumentUploader(maxConcurrent: 2, transport: transport, strategy: strategy)

        try await withThrowingTaskGroup(of: UploadReceipt.self) { group in
            for doc in docs(6) { group.addTask { try await uploader.upload(doc) } }
            for try await _ in group {}
        }

        #expect(await transport.peak == 2)
        #expect(await transport.sent.count == 6)
        #expect(await uploader.limiter.availablePermits == 2)
    }

    @Test(arguments: DocumentUploader.ReleaseStrategy.allCases)
    func releasesThePermitWhenTheUploadThrows(strategy: DocumentUploader.ReleaseStrategy) async {
        let transport = RecordingTransport(failing: ["d1"])
        let uploader = DocumentUploader(maxConcurrent: 1, transport: transport, strategy: strategy)

        await #expect(throws: UploadError.rejected(reason: "bad d1")) {
            try await uploader.upload(docs(1)[0])
        }
        // Checked right after return: the defer body already ran, no fire-and-forget Task.
        #expect(await uploader.limiter.availablePermits == 1)
    }

    @Test(arguments: DocumentUploader.ReleaseStrategy.allCases)
    func releasesThePermitWhenCancelledWhileWaiting(strategy: DocumentUploader.ReleaseStrategy) async throws {
        let transport = RecordingTransport(delay: .milliseconds(200))
        let uploader = DocumentUploader(maxConcurrent: 1, transport: transport, strategy: strategy)
        let all = docs(2)

        let first = Task { try await uploader.upload(all[0]) }
        try await waitUntil { await transport.sent.count == 1 }
        let second = Task { try await uploader.upload(all[1]) }
        try await waitUntil { await uploader.limiter.waitingCount == 1 }
        second.cancel()

        _ = try await first.value
        await #expect(throws: CancellationError.self) { try await second.value }
        #expect(await transport.sent == ["d1"]) // the cancelled one never hit the network
        #expect(await uploader.limiter.availablePermits == 1)
    }

    @Test func waitersAreServedInFIFOOrder() async throws {
        let transport = RecordingTransport(delay: .milliseconds(30))
        let uploader = DocumentUploader(maxConcurrent: 1, transport: transport)
        let all = docs(4)

        let first = Task { try await uploader.upload(all[0]) }
        try await waitUntil { await transport.sent.count == 1 }
        var rest: [Task<UploadReceipt, any Error>] = []
        for (index, doc) in all.dropFirst().enumerated() {
            rest.append(Task { try await uploader.upload(doc) })
            try await waitUntil { await uploader.limiter.waitingCount == index + 1 }
        }
        _ = try await first.value
        for task in rest { _ = try await task.value }

        #expect(await transport.sent == ["d1", "d2", "d3", "d4"])
    }
}

/// Polls a condition with a timeout instead of a fixed sleep.
func waitUntil(timeout: Duration = .seconds(2), _ condition: @Sendable () async -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while await !condition() {
        guard clock.now < deadline else {
            Issue.record("condition not met in time")
            return
        }
        try await Task.sleep(for: .milliseconds(2))
    }
}
