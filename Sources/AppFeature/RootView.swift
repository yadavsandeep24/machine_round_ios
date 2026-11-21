import Core
import ImageCache
import SwiftUI

public struct RootView: View {
    let dependencies: AppDependencies
    private let pipeline = ImagePipeline(countLimit: 150)

    public init(dependencies: AppDependencies = .live()) {
        self.dependencies = dependencies
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 4) {
                    // Duplicate ids on purpose: many cells share URLs, one download each.
                    ForEach(0..<300, id: \.self) { index in
                        CachedImage(
                            url: URL(string: "https://picsum.photos/id/\(index % 60)/600/600"),
                            pipeline: pipeline,
                            pointSize: 100
                        )
                    }
                }
            }
            .navigationTitle("Image cache")
        }
        .tint(Theme.accent)
    }
}
