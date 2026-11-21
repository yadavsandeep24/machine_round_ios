# Machine Round iOS: `feature/post-detail`

> Diff against the previous step: `git diff 02-posts-list..feature/post-detail`

## This step: detail screen
- **Value-based navigation:** `NavigationLink(value: post.id)` + `.navigationDestination(for: Int.self)`; the destination is built lazily and deep links only need the id.
- **`async let`** loads the post and its comments in parallel; both are cancelled together when the view disappears (structured concurrency). A comments failure shows inline and does not fail the screen.
- **`.task(id:)`** restarts the load (cancelling the old one) if the id changes.
- **Cache first, network fallback** in `LivePostRepository.post(id:)` for posts that were never cached.
- **Cancellation:** a cancelled load leaves the state untouched instead of showing an error (tested).
- Tests: 5 more for the detail view model. 15 total.

---

## Earlier step: `02-posts-list`

A basic feature on top of `01-minimal`: fetch posts from `jsonplaceholder.typicode.com`, cache them (offline-first), and show loading, error with Retry, empty and success states with pull-to-refresh.

```
Sources/Posts/
  Post.swift              Codable, Identifiable, Hashable, Sendable
  PostRepository.swift    protocol + LivePostRepository (APIClient + KeyValueStore cache)
  PostsViewModel.swift    @MainActor @Observable; state: Loadable<[Post]>, isRefreshing, bannerError
  PostsView.swift         switch over state; List + .refreshable; .task for loading
```

## Data flow
```
.task ─► load(): cache → state = .loaded(cache) (instant) ─► refresh() ─► repository ─► API ─► cache written
.refreshable ─► refresh() (guarded: one at a time)
```
- **Offline-first:** an error with cached data shows a banner over the list; with no cache, the full-screen error + Retry.
- **`.task`, not `.onAppear { Task { } }`:** the task is cancelled automatically when the view disappears; the view model treats `.cancelled` as a non-error (tested).
- **`@State` owns the `@Observable` model:** created once per view identity, survives re-renders.
- **Duplicate refreshes dropped** (tested with a gated fake).

## Tests (10)
Core (5) + view model (5): network into empty cache, full-screen failure, cached data + banner, cancellation is not an error, refresh while refreshing dropped.

## Branch ladder
`02-posts-list` → `feature/post-detail` → `feature/pagination-manual` → `feature/search-debounce` → `main`.