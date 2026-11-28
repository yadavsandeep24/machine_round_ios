import Foundation

public struct Document: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let sizeKB: Int

    public init(id: String, name: String, sizeKB: Int) {
        self.id = id
        self.name = name
        self.sizeKB = sizeKB
    }
}

public struct UploadReceipt: Equatable, Sendable {
    public let documentID: String
    public let remoteURL: URL
}

public enum UploadError: Error, Equatable, Sendable {
    case rejected(reason: String)
}

/// The network call. Swappable so tests control timing and failures.
public protocol UploadTransport: Sendable {
    func send(_ document: Document) async throws -> UploadReceipt
}

/// Demo transport for the app: takes ~1 ms per KB and rejects files named "blurry".
public struct SimulatedTransport: UploadTransport {
    public init() {}

    public func send(_ document: Document) async throws -> UploadReceipt {
        try await Task.sleep(for: .milliseconds(document.sizeKB))
        if document.name.localizedCaseInsensitiveContains("blurry") {
            throw UploadError.rejected(reason: "Image is too blurry")
        }
        return UploadReceipt(documentID: document.id, remoteURL: URL(string: "https://files.example.com/\(document.id)")!)
    }
}
