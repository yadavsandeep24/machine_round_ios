import Core
import SwiftUI
import Uploads

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack {
            DocumentUploadView()
        }
        .tint(Theme.accent)
    }
}

#Preview { RootView(dependencies: AppDependencies(api: APIClient(baseURL: Endpoints.jsonPlaceholder), store: InMemoryStore())) }
