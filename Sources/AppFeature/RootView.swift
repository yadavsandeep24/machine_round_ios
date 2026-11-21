import Core
import SwiftUI

public struct RootView: View {
    public init() {}

    public var body: some View {
        Text("Start here")
            .font(.title2)
            .tint(Theme.accent)
    }
}

#Preview { RootView() }
