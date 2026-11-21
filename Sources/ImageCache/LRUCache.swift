/// Tiny LRU with a count limit. Deterministic (unlike NSCache, which evicts
/// whenever the system likes), so the eviction policy can be unit-tested.
/// In production, pair or replace with NSCache (cost = width * height * 4 bytes)
/// so the OS can purge it under memory pressure.
struct LRUCache<Key: Hashable, Value> {
    private var values: [Key: Value] = [:]
    private var order: [Key] = [] // least recent first
    let countLimit: Int

    init(countLimit: Int) { self.countLimit = max(1, countLimit) }

    mutating func value(for key: Key) -> Value? {
        guard let value = values[key] else { return nil }
        touch(key)
        return value
    }

    mutating func insert(_ value: Value, for key: Key) {
        values[key] = value
        touch(key)
        while order.count > countLimit {
            values.removeValue(forKey: order.removeFirst())
        }
    }

    mutating func removeAll() {
        values.removeAll()
        order.removeAll()
    }

    var count: Int { values.count }

    private mutating func touch(_ key: Key) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}
