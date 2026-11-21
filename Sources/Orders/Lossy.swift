import Foundation
import os

/// Decodes an array element by element and SKIPS elements that fail, logging
/// why, instead of failing the whole response.
///
/// The decision to state in the interview: lossy for display lists (one bad
/// row should not blank the screen; log it so the backend gets fixed); strict
/// for data where a missing item is dangerous (a payment's line items, a
/// balance): fail and show an error.
@propertyWrapper
public struct Lossy<Element: Decodable & Sendable>: Decodable, Sendable {
    public var wrappedValue: [Element]
    /// Why each skipped element failed (also logged).
    public private(set) var skipped: [String] = []

    public var projectedValue: Lossy<Element> { self }

    public init(wrappedValue: [Element]) { self.wrappedValue = wrappedValue }

    private struct AnyDecodable: Decodable {}

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        var skipped: [String] = []
        while !container.isAtEnd {
            do {
                elements.append(try container.decode(Element.self))
            } catch {
                _ = try? container.decode(AnyDecodable.self) // move past the bad element
                skipped.append(String(describing: error))
                Logger(subsystem: "MachineRound", category: "decoding")
                    .error("Skipped \(Element.self, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        self.wrappedValue = elements
        self.skipped = skipped
    }
}
