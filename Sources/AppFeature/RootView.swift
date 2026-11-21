import Challenges
import Core
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        NavigationStack { ChallengesView() }
            .tint(Theme.accent)
    }
}
