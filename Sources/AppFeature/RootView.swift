import Core
import SwiftUI
import Weather

public struct RootView: View {
    let dependencies: AppDependencies

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    public var body: some View {
        WeatherRootView(store: WeatherStore(service: OpenMeteoService(), store: dependencies.store))
            .tint(Theme.accent)
    }
}
