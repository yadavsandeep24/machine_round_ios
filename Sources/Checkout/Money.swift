import Foundation

/// Integer minor units (paise/cents). Never Double for money.
public struct Money: Hashable, Codable, Sendable {
    public let minor: Int64
    public let currency: String

    public init(minor: Int64, currency: String = "INR") {
        self.minor = minor
        self.currency = currency
    }

    public var decimal: Decimal { Decimal(minor) / 100 }

    public var formatted: String {
        decimal.formatted(.currency(code: currency).locale(Locale(identifier: "en_IN")))
    }

    public static func sum(_ items: [Money], currency: String = "INR") throws -> Money {
        guard items.allSatisfy({ $0.currency == currency }) else { throw MoneyError.currencyMismatch }
        return Money(minor: items.reduce(0) { $0 + $1.minor }, currency: currency)
    }
}

public enum MoneyError: Error { case currencyMismatch }
