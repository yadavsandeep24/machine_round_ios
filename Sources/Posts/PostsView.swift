import Core
import SwiftUI

public struct PostsView: View {
    @State private var model: PostsViewModel

    public init(model: PostsViewModel) {
        _model = State(initialValue: model)
    }

    public var body: some View {
        content
            .navigationTitle("Posts")
            .task { await model.load() }
            .navigationDestination(for: Int.self) { id in
                PostDetailView(model: PostDetailViewModel(postId: id, repository: model.repository))
            }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading(previous: nil):
            LoadingView()
        case .failed(let error, previous: nil):
            ErrorView(message: error.userMessage, retry: model.retry)
        case .loaded(let posts), .loading(previous: let posts?), .failed(_, previous: let posts?):
            List {
                if let banner = model.bannerError {
                    Text(banner.userMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.red.opacity(0.08))
                }
                ForEach(posts) { post in
                    // Value-based navigation: the destination is built lazily from the id.
                    NavigationLink(value: post.id) { PostRow(post: post) }
                }
            }
            .listStyle(.plain)
            .overlay {
                if posts.isEmpty { EmptyStateView("No posts yet", systemImage: "doc.text") }
            }
            .refreshable { await model.refresh() }
        }
    }
}

struct PostRow: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.title).font(.headline).lineLimit(1)
            Text(post.body).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
