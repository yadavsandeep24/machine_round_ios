import Auth
import Core
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        AuthRootView(session: SessionModel(tokens: KeychainTokenStore()))
            .tint(Theme.accent)
    }
}
