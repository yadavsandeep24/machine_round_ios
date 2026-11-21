# Machine Round iOS: `feature/search-debounce`

> Diff against the previous step: `git diff feature/pagination-manual..feature/search-debounce`

## This step: server-side search with debounce and cancellation
```
.searchable(text: $model.query)        typing updates query instantly (no lag)
.task(id: model.query) { search(query) }   a new keystroke CANCELS the previous task
search(): blank → clear now; same query already loaded → skip (distinct)
          try await Task.sleep(300ms)   ← debounce = cancellable sleep
          results = try await repository.search(q)
          try Task.checkCancellation()  ← drop a stale response
```
- **Why cancel, not just delay:** a delay alone still lets a slow response for "kot" land after "swift". Cancellation + `checkCancellation()` drops it (tested with a slow older query).
- **`@Bindable var model = model`** inside `body` gives a binding to an `@Observable` model held in `@State`.
- **Retry** calls `search(query, force: true)` (skips debounce and distinct). Results are not cached; old results stay visible under a spinner.
- **Combine alternative:** `$query.debounce(for: 0.3, scheduler: RunLoop.main).removeDuplicates().map { … }.switchToLatest()`; name it, but structured concurrency is the 2026 default.
- Tests: 4 search tests (one request for fast typing, stale response dropped, distinct, error/retry/clear). 23 total.

---

## Earlier step: `feature/pagination-manual`

> Diff against the previous step: `git diff feature/post-detail..feature/pagination-manual`

## This step: hand-written load-more
- **Trigger:** each row's `.task` calls `loadMoreIfNeeded(currentItem:)`; only rows within 5 of the end load the next page (tested). `.task` instead of `.onAppear` so it is cancelled when the row scrolls away.
- **Guards:** one load at a time, never while refreshing, never past the end, never before page 1 succeeded, no auto-retry after an error (footer Retry passes `isRetry`).
- **Refresh vs in-flight load-more:** a `generation` counter; a page that started before a refresh is dropped instead of being appended onto the new page 1 (tested with a gate).
- **Dedupe by id**; **only page 1 is cached**; end = a short page (prefer `hasMore` / `nextCursor` if the API has one).
- Tests: 4 pagination tests. 19 total.

---

## Earlier step: `feature/post-detail`

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