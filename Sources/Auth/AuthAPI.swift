import Core
import Foundation

public struct Profile: Decodable, Equatable, Sendable {
    public let id: Int
    public let username: String
    public let firstName: String
    public let email: String
}

/// Unauthenticated endpoints on a PLAIN client (no auth wrapper), so a
/// failing refresh can never recurse into another refresh.
public struct AuthAPI: Sendable {
    public static let baseURL = URL(string: "https://dummyjson.com/")!
    private let api: APIClient

    public init(http: any HTTPClient = URLSession.shared) {
        api = APIClient(baseURL: Self.baseURL, http: http)
    }

    public func login(username: String, password: String) async throws(AppError) -> Session {
        try await post("auth/login", ["username": username, "password": password, "expiresInMins": "30"])
    }

    public func refresh(_ refreshToken: String) async throws(AppError) -> Session {
        try await post("auth/refresh", ["refreshToken": refreshToken, "expiresInMins": "30"])
    }

    private func post(_ path: String, _ body: [String: String]) async throws(AppError) -> Session {
        var request = URLRequest(url: Self.baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        return try await api.send(request)
    }
}
