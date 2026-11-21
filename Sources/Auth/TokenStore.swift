import Foundation
import Security

public struct Session: Codable, Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

public protocol TokenStore: Sendable {
    func load() -> Session?
    func save(_ session: Session)
    func clear()
}

/// Tokens in the Keychain, NOT UserDefaults (a plain plist readable from
/// backups and on jailbroken devices).
/// `WhenUnlockedThisDeviceOnly`: unreadable while the device is locked and
/// never restored onto another device from a backup.
public struct KeychainTokenStore: TokenStore {
    private let service: String
    private let account = "session"

    public init(service: String = "com.example.machineround.auth") { self.service = service }

    private var baseQuery: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: account]
    }

    public func load() -> Session? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    public func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        if SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(baseQuery.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }

    public func clear() { SecItemDelete(baseQuery as CFDictionary) }
}

public final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: Session?
    public init(_ session: Session? = nil) { self.session = session }
    public func load() -> Session? { lock.withLock { session } }
    public func save(_ session: Session) { lock.withLock { self.session = session } }
    public func clear() { lock.withLock { session = nil } }
}
