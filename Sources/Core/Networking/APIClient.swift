import Foundation

/// The seam for tests: production uses URLSession, tests use a stub.
public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

/// Thin typed client: builds the URL, checks the status, decodes, and maps
/// every failure to `AppError`. Repositories call this; views never do.
public struct APIClient: Sendable {
    public let baseURL: URL
    private let http: any HTTPClient
    private let decoder: JSONDecoder

    public init(baseURL: URL, http: any HTTPClient = URLSession.shared, decoder: JSONDecoder = JSONDecoder()) {
        self.baseURL = baseURL
        self.http = http
        self.decoder = decoder
    }

    public func get<T: Decodable & Sendable>(
        _ path: String,
        query: [String: String] = [:],
        headers: [String: String] = [:],
        as type: T.Type = T.self
    ) async throws(AppError) -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!, timeoutInterval: 15)
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return try await send(request)
    }

    public func send<T: Decodable & Sendable>(_ request: URLRequest, as type: T.Type = T.self) async throws(AppError) -> T {
        do {
            let (data, response) = try await http.data(for: request)
            if let http = response as? HTTPURLResponse, let error = AppError.fromStatus(http.statusCode) {
                throw error
            }
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.map(error)
        }
    }
}

public enum Endpoints {
    public static let jsonPlaceholder = URL(string: "https://jsonplaceholder.typicode.com/")!
}
