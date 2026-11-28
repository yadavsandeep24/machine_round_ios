import Core
import SwiftUI

public struct DocumentUploadView: View {
    @State private var model: DocumentUploadViewModel

    public init(model: DocumentUploadViewModel = .demo()) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        List {
            Section {
                ForEach(model.documents) { document in
                    row(document, status: model.statuses[document.id] ?? .queued)
                }
            } footer: {
                Text("At most 2 uploads run at once. Each one gives its slot back in an async defer.")
            }
        }
        .navigationTitle("KYC documents")
        .safeAreaInset(edge: .bottom) {
            HStack {
                Text("\(model.uploadedCount)/\(model.documents.count) uploaded").font(.subheadline)
                Spacer()
                if model.isUploading {
                    Button("Cancel", role: .cancel) { model.cancel() }
                } else {
                    Button("Upload all") { model.uploadAll() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canStart)
                }
            }
            .padding()
            .background(.bar)
        }
    }

    private func row(_ document: Document, status: DocumentUploadViewModel.Status) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(document.name)
                Text("\(document.sizeKB) KB").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch status {
            case .queued: Image(systemName: "clock").foregroundStyle(.secondary)
            case .uploading: ProgressView()
            case .uploaded: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .failed(let reason): Label(reason, systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.caption)
            case .cancelled: Image(systemName: "stop.circle").foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension DocumentUploadViewModel {
    public static func demo() -> DocumentUploadViewModel {
        DocumentUploadViewModel(
            documents: [
                Document(id: "pan", name: "PAN card", sizeKB: 600),
                Document(id: "aadhaar-front", name: "Aadhaar front", sizeKB: 900),
                Document(id: "aadhaar-back", name: "Aadhaar back (blurry)", sizeKB: 700),
                Document(id: "selfie", name: "Selfie", sizeKB: 1200),
                Document(id: "bank", name: "Bank statement", sizeKB: 1500),
            ],
            uploader: DocumentUploader(maxConcurrent: 2, transport: SimulatedTransport())
        )
    }
}

#Preview { NavigationStack { DocumentUploadView() } }
