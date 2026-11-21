import Core
import Foundation

public struct TxnPage: Sendable, Equatable {
    public let items: [Transaction]
    /// Opaque cursor; nil at the end. Cursor (not page number) paging stays
    /// correct when new transactions arrive at the top.
    public let nextCursor: String?
}

public protocol TransactionAPI: Sendable {
    func list(_ filter: TxnFilter, cursor: String?) async throws(AppError) -> TxnPage
}

/// In-memory "server" (filtering is server-side) for the demo and tests.
public struct FakeTransactionAPI: TransactionAPI {
    public let all: [Transaction]
    public var pageSize = 20
    public var latency: Duration = .milliseconds(400)

    public init(all: [Transaction], pageSize: Int = 20, latency: Duration = .milliseconds(400)) {
        self.all = all
        self.pageSize = pageSize
        self.latency = latency
    }

    public func list(_ filter: TxnFilter, cursor: String?) async throws(AppError) -> TxnPage {
        do { try await Task.sleep(for: latency) } catch { throw .cancelled }
        let filtered = all.filter(filter.matches)
        let start = cursor.flatMap { c in filtered.firstIndex { $0.id == c }.map { $0 + 1 } } ?? 0
        let items = Array(filtered.dropFirst(start).prefix(pageSize))
        let more = start + pageSize < filtered.count
        return TxnPage(items: items, nextCursor: more ? items.last?.id : nil)
    }

    /// Deterministic sample data, newest first, one every 5 hours.
    public static func sample(count: Int, newest: Date = .now) -> [Transaction] {
        let merchants = ["Swiggy", "Amazon", "Uber", "Airtel", "Zomato", "BigBasket", "IRCTC", "Netflix"]
        let people = ["Rahul", "Priya", "Amit", "Sneha"]
        return (0..<count).map { i in
            let credit = i % 5 == 0
            return Transaction(
                id: "txn_\(i + 1)",
                kind: credit ? .credit : .debit,
                status: i % 13 == 7 ? .failed : i % 11 == 3 ? .pending : .success,
                amountMinor: Int64((i * 7919) % 500_000 + 1000),
                counterparty: credit ? people[i % people.count] : merchants[i % merchants.count],
                note: credit ? "Received via UPI" : nil,
                createdAt: newest.addingTimeInterval(-Double(i) * 5 * 3600)
            )
        }
    }
}
