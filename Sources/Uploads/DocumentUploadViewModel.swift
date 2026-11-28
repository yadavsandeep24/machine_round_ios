import Core
import Foundation
import Observation

@MainActor
@Observable
public final class DocumentUploadViewModel {
    public enum Status: Equatable, Sendable {
        case queued
        case uploading
        case uploaded(URL)
        case failed(String)
        case cancelled
    }

    public private(set) var documents: [Document]
    public private(set) var statuses: [Document.ID: Status]
    public private(set) var isUploading = false

    private let uploader: DocumentUploader
    private var batch: Task<Void, Never>?

    public init(documents: [Document], uploader: DocumentUploader) {
        self.documents = documents
        self.uploader = uploader
        self.statuses = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, .queued) })
    }

    public var uploadedCount: Int {
        statuses.values.filter { if case .uploaded = $0 { true } else { false } }.count
    }

    public var canStart: Bool {
        !isUploading && documents.contains { !isDone(statuses[$0.id] ?? .queued) }
    }

    /// Starts every pending document at once; the uploader's semaphore keeps only N in flight.
    public func uploadAll() {
        guard canStart else { return }
        let pending = documents.filter { !isDone(statuses[$0.id] ?? .queued) }
        pending.forEach { statuses[$0.id] = .queued }
        isUploading = true
        batch = Task {
            await withTaskGroup(of: Void.self) { group in
                for document in pending {
                    group.addTask { await self.upload(document) }
                }
            }
            isUploading = false
        }
    }

    public func cancel() {
        batch?.cancel()
    }

    /// For tests: wait for the current batch.
    public func waitForBatch() async {
        await batch?.value
    }

    private func upload(_ document: Document) async {
        statuses[document.id] = .uploading
        do {
            let receipt = try await uploader.upload(document)
            statuses[document.id] = .uploaded(receipt.remoteURL)
        } catch is CancellationError {
            statuses[document.id] = .cancelled
        } catch UploadError.rejected(let reason) {
            statuses[document.id] = .failed(reason)
        } catch {
            statuses[document.id] = .failed(AppError.map(error).userMessage)
        }
    }

    private func isDone(_ status: Status) -> Bool {
        if case .uploaded = status { true } else { false }
    }
}
