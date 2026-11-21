import Core
import Foundation
import Testing
@testable import Transactions

let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
    return c
}()
func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}
func txn(_ id: String, _ at: Date, _ kind: Transaction.Kind = .debit, _ minor: Int64 = 10_000, _ status: Transaction.Status = .success) -> Transaction {
    Transaction(id: id, kind: kind, status: status, amountMinor: minor, counterparty: "X", createdAt: at)
}

@Suite struct GroupingTests {
    let now = date(2026, 11, 22, 15)

    @Test func todayYesterdayAndDatesInOrder() {
        let s = DayGrouping.sections([
            txn("a", date(2026, 11, 22, 9)), txn("b", date(2026, 11, 22, 1)), txn("c", date(2026, 11, 21)),
            txn("d", date(2026, 11, 3)), txn("e", date(2025, 12, 31)),
        ], now: now, calendar: calendar)
        #expect(s.map(\.title) == ["Today", "Yesterday", "3 Nov", "31 Dec 2025"])
        #expect(s[0].items.map(\.id) == ["a", "b"])
    }

    @Test func netCountsOnlySuccessful() {
        let s = DayGrouping.sections([
            txn("a", date(2026, 11, 22), .credit, 50_000), txn("b", date(2026, 11, 22), .debit, 20_000),
            txn("c", date(2026, 11, 22), .debit, 99_900, .failed),
        ], now: now, calendar: calendar)
        #expect(s[0].netMinor == 30_000)
        #expect(s[0].netText == "+₹300.00")
    }

    @Test func signedINR() {
        #expect(txn("a", now, .credit, 125_000).signedAmount == "+₹1,250.00")
        #expect(txn("b", now, .debit, 25_050).signedAmount == "−₹250.50")
    }
}

final class CountingAPI: TransactionAPI, @unchecked Sendable {
    let inner: FakeTransactionAPI
    private let lock = NSLock()
    private(set) var calls: [(TxnFilter, String?)] = []
    var failNext = false
    init(_ inner: FakeTransactionAPI) { self.inner = inner }
    func list(_ filter: TxnFilter, cursor: String?) async throws(AppError) -> TxnPage {
        let fail = lock.withLock { () -> Bool in calls.append((filter, cursor)); defer { failNext = false }; return failNext }
        if fail { throw .noInternet }
        return try await inner.list(filter, cursor: cursor)
    }
}

@MainActor
@Suite struct TransactionsViewModelTests {
    let all = FakeTransactionAPI.sample(count: 45)

    @Test func firstPageThenCursorPagesUntilTheEnd() async {
        let api = CountingAPI(FakeTransactionAPI(all: all, latency: .zero))
        let model = TransactionsViewModel(api: api)
        await model.reload()
        await model.loadMore()
        await model.loadMore()
        await model.loadMore() // end: ignored
        #expect(model.items.count == 45)
        #expect(api.calls.map(\.1) == [nil, "txn_20", "txn_40"])
    }

    @Test func aFilterChangeCancelsTheOldLoad() async {
        let model = TransactionsViewModel(api: FakeTransactionAPI(all: all, latency: .milliseconds(100)))
        let old = Task { await model.reload() } // what .task(id: filter) does…
        try? await Task.sleep(for: .milliseconds(20))
        old.cancel()                             // …when the filter changes
        model.kind = .credit
        await model.reload()
        await old.value
        #expect(model.items.allSatisfy { $0.kind == .credit })
        #expect(!model.items.isEmpty)
    }

    @Test func searchIsDebouncedIntoTheServerQuery() async {
        let model = TransactionsViewModel(api: FakeTransactionAPI(all: all, latency: .zero), debounce: .milliseconds(30))
        model.searchText = "netflix"
        await model.debounceSearch()
        await model.reload()
        #expect(model.query == "netflix")
        #expect(model.items.allSatisfy { $0.counterparty == "Netflix" })
    }

    @Test func firstPageErrorThenRetry() async {
        let api = CountingAPI(FakeTransactionAPI(all: all, latency: .zero))
        api.failNext = true
        let model = TransactionsViewModel(api: api)
        await model.reload()
        #expect(model.phase == .failed(.noInternet))
        await model.reload()
        #expect(model.phase == .ready)
    }
}
