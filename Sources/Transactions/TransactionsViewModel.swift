import Core
import Foundation
import Observation

@MainActor
@Observable
public final class TransactionsViewModel {
    public var kind: Transaction.Kind?
    public var status: Transaction.Status?
    /// Bound to `.searchable`; debounced into `query`.
    public var searchText = ""
    public private(set) var query = ""

    public private(set) var items: [Transaction] = []
    public private(set) var phase: Phase = .loading
    public private(set) var isLoadingMore = false
    public private(set) var loadMoreFailed = false
    @ObservationIgnored private var cursor: String?
    @ObservationIgnored private var loadedFilter: TxnFilter?

    public enum Phase: Equatable { case loading, ready, failed(AppError) }

    /// The server query. The view runs `.task(id: filter) { await reload() }`,
    /// so a filter change cancels the old load and starts from page 1.
    public var filter: TxnFilter { TxnFilter(kind: kind, status: status, query: query) }

    public var hasMore: Bool { cursor != nil }

    @ObservationIgnored private let api: any TransactionAPI
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let debounce: Duration

    public init(api: any TransactionAPI, now: @escaping @Sendable () -> Date = { .now }, debounce: Duration = .milliseconds(300)) {
        self.api = api
        self.now = now
        self.debounce = debounce
    }

    /// Derived for the view. (Cache it if lists get big: it runs per body evaluation.)
    public var sections: [DaySection] { DayGrouping.sections(items, now: now()) }

    /// `.task(id: searchText)`: cancellable sleep = debounce. Blank is instant.
    public func debounceSearch() async {
        let text = searchText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            do { try await Task.sleep(for: debounce) } catch { return }
        }
        query = text
    }

    public func reload() async {
        let filter = self.filter
        phase = items.isEmpty || loadedFilter != filter ? .loading : phase
        do {
            let page = try await api.list(filter, cursor: nil)
            try Task.checkCancellation() // superseded by a newer filter
            items = page.items
            cursor = page.nextCursor
            loadedFilter = filter
            loadMoreFailed = false
            phase = .ready
        } catch let error as AppError where !error.isCancellation {
            phase = items.isEmpty ? .failed(error) : .ready
        } catch {}
    }

    public func loadMore(isRetry: Bool = false) async {
        guard phase == .ready, let cursor, !isLoadingMore, !loadMoreFailed || isRetry else { return }
        let filter = self.filter
        isLoadingMore = true
        loadMoreFailed = false
        defer { isLoadingMore = false }
        do {
            let page = try await api.list(filter, cursor: cursor)
            guard filter == loadedFilter else { return } // filter changed meanwhile
            let seen = Set(items.map(\.id))
            items += page.items.filter { !seen.contains($0.id) }
            self.cursor = page.nextCursor
        } catch let error where !error.isCancellation {
            loadMoreFailed = true
        } catch {}
    }
}
