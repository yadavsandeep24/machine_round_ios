import Core
import Foundation
import Observation

@MainActor
@Observable
public final class SessionModel {
    public enum Status: Equatable { case restoring, signedOut, signedIn }
    public private(set) var status: Status = .restoring
    public private(set) var expired = false

    @ObservationIgnored private let tokens: any TokenStore
    @ObservationIgnored private let authAPI: AuthAPI
    @ObservationIgnored public let api: APIClient
    /// The refresher (an actor) reports expiry through a stream: no shared
    /// mutable reference to this MainActor object crosses isolation.
    @ObservationIgnored private let expiryEvents: AsyncStream<Void>

    /// Wires the refresher and the authorized client; `http` is injectable for tests.
    public init(tokens: any TokenStore, http: any HTTPClient = URLSession.shared) {
        self.tokens = tokens
        let authAPI = AuthAPI(http: http)
        self.authAPI = authAPI
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        expiryEvents = stream
        let refresher = TokenRefresher(
            tokens: tokens,
            refresh: { token throws(AppError) in try await authAPI.refresh(token) },
            onExpired: { continuation.yield() }
        )
        api = APIClient(baseURL: AuthAPI.baseURL, http: AuthorizedHTTPClient(base: http, refresher: refresher))
    }

    /// Restores from the Keychain at launch, without a network call.
    public func restore() {
        status = tokens.load() == nil ? .signedOut : .signedIn
    }

    public func signIn(username: String, password: String) async throws(AppError) {
        let session = try await authAPI.login(username: username, password: password)
        tokens.save(session)
        expired = false
        status = .signedIn
    }

    public func signOut() {
        tokens.clear()
        status = .signedOut
    }

    /// Run from the root view's `.task`; ends when the view goes away.
    public func observeExpiry() async {
        for await _ in expiryEvents { sessionExpired() }
    }

    func sessionExpired() {
        expired = true
        status = .signedOut
    }

    public func profile() async throws(AppError) -> Profile {
        try await api.get("auth/me")
    }
}
