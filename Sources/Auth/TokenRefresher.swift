import Core
import Foundation

/// Single-flight token refresh. An actor serialises access, and the in-flight
/// `Task` is shared: 5 parallel 401s → ONE refresh call; the others await it.
/// Only 400/401/403 from the refresh endpoint ends the session; a 5xx or a
/// network error keeps it (the user may just be offline).
public actor TokenRefresher {
    private let tokens: any TokenStore
    private let refreshCall: @Sendable (String) async throws(AppError) -> Session
    private let onExpired: @Sendable () -> Void
    private var inFlight: Task<String?, any Error>?

    public init(
        tokens: any TokenStore,
        refresh: @escaping @Sendable (String) async throws(AppError) -> Session,
        onExpired: @escaping @Sendable () -> Void
    ) {
        self.tokens = tokens
        self.refreshCall = refresh
        self.onExpired = onExpired
    }

    public func currentAccessToken() -> String? { tokens.load()?.accessToken }

    /// Returns a usable access token, or nil when the session is over.
    public func validToken(after rejected: String?) async throws -> String? {
        if let current = tokens.load()?.accessToken, current != rejected {
            return current // someone else refreshed while this request was in flight
        }
        if let inFlight { return try await inFlight.value }
        let task = Task<String?, any Error> { [tokens, refreshCall, onExpired] in
            guard let session = tokens.load() else { return nil }
            do {
                let fresh = try await refreshCall(session.refreshToken)
                tokens.save(fresh)
                return fresh.accessToken
            } catch let error as AppError where error == .unauthorized || error == .server(status: 400) {
                // 401/403 map to .unauthorized; dummyjson answers 400 for a bad refresh token.
                tokens.clear()
                onExpired()
                return nil
            }
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}

/// Wraps any HTTPClient: adds the bearer token, refreshes once on 401, retries once.
public struct AuthorizedHTTPClient: HTTPClient {
    private let base: any HTTPClient
    private let refresher: TokenRefresher

    public init(base: any HTTPClient, refresher: TokenRefresher) {
        self.base = base
        self.refresher = refresher
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let token = await refresher.currentAccessToken()
        let first = try await base.data(for: request.withBearer(token))
        guard (first.1 as? HTTPURLResponse)?.statusCode == 401 else { return first }
        guard let fresh = try await refresher.validToken(after: token) else { return first } // session over
        return try await base.data(for: request.withBearer(fresh)) // retried once, never loops
    }
}

extension URLRequest {
    func withBearer(_ token: String?) -> URLRequest {
        var copy = self
        if let token { copy.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return copy
    }
}
