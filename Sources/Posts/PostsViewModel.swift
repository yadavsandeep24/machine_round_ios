import Core
import Observation

/// @Observable (iOS 17): views re-render only for the properties they read.
/// @MainActor: all state changes happen on the main thread, checked by the compiler.
@MainActor
@Observable
public final class PostsViewModel {
    public private(set) var state: Loadable<[Post]> = .idle
    public private(set) var isRefreshing = false
    /// Shown as a banner when cached posts are on screen.
    public private(set) var bannerError: AppError?

    let repository: any PostRepository

    public init(repository: any PostRepository) {
        self.repository = repository
    }

    /// Called from `.task`: runs once per appearance and is cancelled on disappear.
    public func load() async {
        guard case .idle = state else { return }
        let cached = repository.cachedPosts()
        state = cached.isEmpty ? .loading(previous: nil) : .loaded(cached)
        await refresh()
    }

    public func refresh() async {
        guard !isRefreshing else { return } // pull-to-refresh spam: one request
        isRefreshing = true
        bannerError = nil
        defer { isRefreshing = false }
        do {
            state = .loaded(try await repository.refresh())
        } catch where error.isCancellation {
            // The user left the screen: not an error.
        } catch {
            if let cached = state.value, !cached.isEmpty {
                bannerError = error
                state = .loaded(cached)
            } else {
                state = .failed(error, previous: nil)
            }
        }
    }

    public func retry() {
        state = .loading(previous: nil)
        Task { await refresh() }
    }
}
