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

    public private(set) var isLoadingMore = false
    public private(set) var hasReachedEnd = false
    /// Footer error. While set, scrolling does not retry; the user taps Retry.
    public private(set) var loadMoreError: AppError?
    private var nextPage = 2
    /// Bumped by every refresh, so a page that started earlier is dropped.
    private var generation = 0

    /// Start loading the next page this many rows before the end.
    static let prefetchDistance = 5

    /// Bound to `.searchable`. Typing updates this instantly (no lag); the
    /// network work happens in `search(_:)`, driven by `.task(id: query)`.
    public var query = ""
    /// Trimmed query the results belong to. Empty = browse mode.
    public private(set) var activeQuery = ""
    public private(set) var searchState: Loadable<[Post]> = .idle
    public var isSearching: Bool { !activeQuery.isEmpty }

    let repository: any PostRepository
    private let debounce: Duration

    public init(repository: any PostRepository, debounce: Duration = .milliseconds(300)) {
        self.repository = repository
        self.debounce = debounce
    }

    /// Debounce = cancellable sleep. `.task(id: query)` cancels this call when
    /// the next keystroke arrives, which cancels the sleep or the request:
    /// that is switchMap / flatMapLatest in Swift Concurrency.
    public func search(_ text: String, force: Bool = false) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { // clearing is instant
            activeQuery = ""
            searchState = .idle
            return
        }
        // distinctUntilChanged: "swift" -> "swif" -> "swift" sends no request.
        if !force, trimmed == activeQuery, case .loaded = searchState { return }
        if !force {
            do { try await Task.sleep(for: debounce) } catch { return } // superseded
        }
        activeQuery = trimmed
        searchState = .loading(previous: searchState.value)
        do {
            let results = try await repository.search(trimmed)
            try Task.checkCancellation() // a newer query started: drop this response
            searchState = .loaded(results)
        } catch is CancellationError {
        } catch let error as AppError where error.isCancellation {
        } catch let error as AppError {
            searchState = .failed(error, previous: nil)
        } catch {}
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
        loadMoreError = nil
        generation += 1
        defer { isRefreshing = false }
        do {
            let page = try await repository.refresh()
            state = .loaded(page.posts)
            nextPage = 2
            hasReachedEnd = page.endReached
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

    /// Called from each row's `.onAppear`: loads when the row is near the end.
    public func loadMoreIfNeeded(currentItem: Post) async {
        guard let posts = state.value,
              let index = posts.firstIndex(where: { $0.id == currentItem.id }),
              index >= posts.count - Self.prefetchDistance else { return }
        await loadMore()
    }

    /// Guards: one load at a time, never while refreshing, never past the end,
    /// never before page 1 succeeded, no auto-retry after an error.
    public func loadMore(isRetry: Bool = false) async {
        guard case .loaded = state,
              !isLoadingMore, !isRefreshing, !hasReachedEnd,
              loadMoreError == nil || isRetry else { return }
        isLoadingMore = true
        loadMoreError = nil
        let startedGeneration = generation
        defer { isLoadingMore = false }
        do {
            let page = try await repository.loadPage(nextPage)
            guard startedGeneration == generation, case .loaded(let latest) = state else { return } // stale
            // Dedupe by id: offset paging can shift items between pages.
            let seen = Set(latest.map(\.id))
            state = .loaded(latest + page.posts.filter { !seen.contains($0.id) })
            nextPage += 1
            hasReachedEnd = page.endReached
        } catch where error.isCancellation {
        } catch {
            if startedGeneration == generation { loadMoreError = error }
        }
    }
}
