import Foundation

/// Storage seam: UserDefaults today, a file / SwiftData / SQLite cache later.
public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String)
    func remove(_ key: String)
}

public extension KeyValueStore {
    /// Corrupt or old-format data is treated as missing instead of crashing.
    func value<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setValue<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { set(data, forKey: key) }
    }
}

public struct UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults
    public init(_ defaults: UserDefaults = .standard) { self.defaults = defaults }
    public func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    public func set(_ data: Data, forKey key: String) { defaults.set(data, forKey: key) }
    public func remove(_ key: String) { defaults.removeObject(forKey: key) }
}

/// Thread-safe in-memory store for tests and previews.
public final class InMemoryStore: KeyValueStore, @unchecked Sendable {
    private var storage: [String: Data]
    private let lock = NSLock()
    public init(_ initial: [String: Data] = [:]) { storage = initial }
    public func data(forKey key: String) -> Data? { lock.withLock { storage[key] } }
    public func set(_ data: Data, forKey key: String) { lock.withLock { storage[key] = data } }
    public func remove(_ key: String) { _ = lock.withLock { storage.removeValue(forKey: key) } }
}
