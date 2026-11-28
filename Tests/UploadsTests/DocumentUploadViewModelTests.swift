import Foundation
import Testing
@testable import Uploads

@MainActor
@Suite struct DocumentUploadViewModelTests {
    @Test func uploadsEverythingAndReportsFailuresPerDocument() async {
        let transport = RecordingTransport(failing: ["d2"])
        let model = DocumentUploadViewModel(documents: docs(3), uploader: DocumentUploader(transport: transport))

        model.uploadAll()
        #expect(model.isUploading)
        await model.waitForBatch()

        #expect(!model.isUploading)
        #expect(model.statuses["d1"] == .uploaded(URL(string: "https://x.test/d1")!))
        #expect(model.statuses["d2"] == .failed("bad d2"))
        #expect(model.uploadedCount == 2)
        #expect(model.canStart) // d2 can be retried
    }

    @Test func retryOnlySendsDocumentsThatAreNotUploaded() async {
        let transport = RecordingTransport(failing: ["d2"])
        let model = DocumentUploadViewModel(documents: docs(3), uploader: DocumentUploader(transport: transport))
        model.uploadAll()
        await model.waitForBatch()

        model.uploadAll()
        await model.waitForBatch()

        let sent = await transport.sent
        #expect(sent.filter { $0 == "d1" }.count == 1)
        #expect(sent.filter { $0 == "d2" }.count == 2)
    }

    @Test func cancelMarksUnfinishedDocumentsAndFreesAllPermits() async throws {
        let transport = RecordingTransport(delay: .seconds(5))
        let uploader = DocumentUploader(maxConcurrent: 2, transport: transport)
        let model = DocumentUploadViewModel(documents: docs(4), uploader: uploader)

        model.uploadAll()
        try await waitUntil { await transport.sent.count == 2 }
        model.cancel()
        await model.waitForBatch()

        #expect(model.documents.allSatisfy { model.statuses[$0.id] == .cancelled })
        #expect(await uploader.limiter.availablePermits == 2)
        #expect(!model.isUploading)
    }
}
