import SwiftUI

public struct LoadingView: View {
    public init() {}
    public var body: some View {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct ErrorView: View {
    let message: String
    let retry: (() -> Void)?
    public init(message: String, retry: (() -> Void)? = nil) {
        self.message = message
        self.retry = retry
    }
    public var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retry { Button("Retry", action: retry).buttonStyle(.borderedProminent) }
        }
    }
}

public struct EmptyStateView: View {
    let message: String
    let systemImage: String
    public init(_ message: String, systemImage: String = "tray") {
        self.message = message
        self.systemImage = systemImage
    }
    public var body: some View {
        ContentUnavailableView(message, systemImage: systemImage)
    }
}

/// Footer for paginated lists: spinner while loading more, retry on error.
public struct LoadMoreFooter: View {
    let isLoading: Bool
    let errorMessage: String?
    let retry: () -> Void
    public init(isLoading: Bool, errorMessage: String?, retry: @escaping () -> Void) {
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.retry = retry
    }
    public var body: some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.secondary).font(.footnote)
                Button("Retry", action: retry)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
