import Foundation

/// Models decoded from a realistic, slightly messy API payload.
public struct OrdersPage: Decodable, Sendable {
    /// `nil` on the last page.
    public let nextCursor: String?
    /// One malformed order must not blank the whole screen: decode lossily.
    @Lossy public var items: [Order]
}

public struct Order: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let createdAt: Date
    /// Money arrives as a STRING ("1250.50") to avoid float rounding; keep it a Decimal.
    public let amount: Decimal
    public let currency: String
    public let status: Status
    /// Optional on purpose: the key can be missing OR null.
    public let couponCode: String?
    /// Missing in old app versions' orders: default instead of failing.
    public let itemsCount: Int

    public enum Status: Hashable, Sendable {
        case placed, delivered, cancelled
        /// New server values must not crash old app versions.
        case unknown(String)
    }

    enum CodingKeys: String, CodingKey {
        // keyDecodingStrategy .convertFromSnakeCase maps created_at → createdAt etc.;
        // only the renamed field needs an explicit key.
        case id = "orderId"
        case createdAt, amount, currency, status, couponCode, itemsCount
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        let rawAmount = try c.decode(String.self, forKey: .amount)
        guard let amount = Decimal(string: rawAmount, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(forKey: .amount, in: c, debugDescription: "Bad amount \(rawAmount)")
        }
        self.amount = amount
        currency = try c.decode(String.self, forKey: .currency)
        let rawStatus = try c.decode(String.self, forKey: .status)
        status = switch rawStatus {
        case "placed": .placed
        case "delivered": .delivered
        case "cancelled": .cancelled
        default: .unknown(rawStatus)
        }
        couponCode = try c.decodeIfPresent(String.self, forKey: .couponCode)
        itemsCount = try c.decodeIfPresent(Int.self, forKey: .itemsCount) ?? 0
    }
}

public enum OrdersDecoder {
    /// Configured once and reused (creating formatters per call is slow).
    public static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // The server sends both "…Z" and "…123Z".
            if let date = try? Date(string, strategy: .iso8601) { return date }
            if let date = try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(string)")
        }
        return decoder
    }()
}
