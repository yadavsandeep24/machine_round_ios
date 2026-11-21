import Core
import SwiftUI

public struct PostDetailView: View {
    @State private var model: PostDetailViewModel

    public init(model: PostDetailViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        Group {
            switch model.state {
            case .loading:
                LoadingView()
            case .failed(let error):
                ErrorView(message: error.userMessage) { Task { await model.load() } }
            case .loaded(let post, let comments, let commentsError):
                List {
                    Section {
                        Text(post.title).font(.title2.bold())
                        Text(post.body)
                    }
                    Section("Comments") {
                        if let commentsError {
                            Text(commentsError.userMessage).foregroundStyle(.red)
                        }
                        ForEach(comments) { comment in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(comment.name).font(.subheadline.bold()).lineLimit(1)
                                Text(comment.email).font(.caption).foregroundStyle(.secondary)
                                Text(comment.body).font(.body)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .navigationTitle("Post")
        // `.task(id:)` restarts (and cancels the old load) if the id changes.
        .task(id: model.postId) { await model.load() }
    }
}
