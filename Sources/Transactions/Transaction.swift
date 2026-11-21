import Foundation

public struct Transaction: Identifiable, Hashable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable, CaseIterable { case credit, debit }
    public enum Status: String, Sendable, Codable, CaseIterable { case success, pending, failed }

    public let id: String
    public let kind: Kind
    public let status: Status
    /// Integer minor units (paise).
    public let amountMinor: Int64
    public let counterparty: String
    public let note: String?
    public let createdAt: Date

    public init(id: String, kind: Kind, status: Status, amountMinor: Int64, counterparty: String, note: String? = nil, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.status = status
        self.amountMinor = amountMinor
        self.counterparty = counterparty
        self.note = note
        self.createdAt = createdAt
    }

    /// "+₹1,250.00" / "−₹250.50"
    public var signedAmount: String { Self.format(minor: amountMinor, credit: kind == .credit) }

    static let inr = Decimal.FormatStyle.Currency(code: "INR").locale(Locale(identifier: "en_IN"))

    static func format(minor: Int64, credit: Bool) -> String {
        (credit ? "+" : "−") + (Decimal(minor) / 100).formatted(inr)
    }
}

public struct TxnFilter: Hashable, Sendable {
    public var kind: Transaction.Kind?
    public var status: Transaction.Status?
    public var query: String = ""
    public init(kind: Transaction.Kind? = nil, status: Transaction.Status? = nil, query: String = "") {
        self.kind = kind
        self.status = status
        self.query = query
    }

    public func matches(_ t: Transaction) -> Bool {
        if let kind, t.kind != kind { return false }
        if let status, t.status != status { return false }
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty || t.counterparty.localizedCaseInsensitiveContains(q) || (t.note ?? "").localizedCaseInsensitiveContains(q)
    }
}

public struct DaySection: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Net of successful transactions, minor units.
    public let netMinor: Int64
    public let items: [Transaction]
    public var netText: String { Transaction.format(minor: abs(netMinor), credit: netMinor >= 0) }
}

public enum DayGrouping {
    /// Groups newest-first transactions by the user's LOCAL calendar day.
    public static func sections(_ txns: [Transaction], now: Date, calendar: Calendar = .current) -> [DaySection] {
        var order: [Date] = []
        var buckets: [Date: [Transaction]] = [:]
        for t in txns {
            let day = calendar.startOfDay(for: t.createdAt)
            if buckets[day] == nil { order.append(day) }
            buckets[day, default: []].append(t)
        }
        return order.map { day in
            let items = buckets[day]!
            let net = items.filter { $0.status == .success }.reduce(Int64(0)) { $0 + ($1.kind == .credit ? $1.amountMinor : -$1.amountMinor) }
            return DaySection(id: day.ISO8601Format(), title: title(for: day, now: now, calendar: calendar), netMinor: net, items: items)
        }
    }

    static func title(for day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: Locale(identifier: "en_IN"), calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated)
        if !calendar.isDate(day, equalTo: now, toGranularity: .year) { style = style.year() }
        return day.formatted(style)
    }
}
