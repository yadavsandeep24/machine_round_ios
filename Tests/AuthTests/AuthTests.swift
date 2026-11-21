import Core
import Foundation
import Testing
@testable import Auth

/// HTTP stub: routes by path, records calls.
final class StubServer: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var paths: [String] = []
    var refreshStatus = 200
    var refreshDelay: Duration = .milliseconds(20)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let path = request.url!.path()
        lock.withLock { paths.append(path) }
        let auth = request.value(forHTTPHeaderField: "Authorization")
        let (status, body): (Int, String)
        switch path {
        case "/auth/login":
            let creds = try JSONDecoder().decode([String: String].self, from: request.httpBody!)
            (status, body) = creds["password"] == "secret12" ? (200, #"{"accessToken":"a1","refreshToken":"r1"}"#) : (400, "{}")
        case "/auth/refresh":
            try await Task.sleep(for: refreshDelay)
            (status, body) = refreshStatus == 200 ? (200, #"{"accessToken":"new","refreshToken":"r2"}"#) : (refreshStatus, "{}")
        default: // protected resources accept "new" (and "a1" for the profile)
            let ok = auth == "Bearer new" || (path == "/auth/me" && auth == "Bearer a1")
            (status, body) = ok ? (200, #"{"id":1,"username":"demo","firstName":"Demo","email":"d@x.dev"}"#) : (401, "{}")
        }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func count(_ path: String) -> Int { lock.withLock { paths.filter { $0 == path }.count } }
}

@Suite struct TokenRefresherTests {
    func client(_ server: StubServer, _ tokens: InMemoryTokenStore, onExpired: @escaping @Sendable () -> Void = {}) -> APIClient {
        let auth = AuthAPI(http: server)
        let refresher = TokenRefresher(tokens: tokens, refresh: { t throws(AppError) in try await auth.refresh(t) }, onExpired: onExpired)
        return APIClient(baseURL: AuthAPI.baseURL, http: AuthorizedHTTPClient(base: server, refresher: refresher))
    }

    @Test func fiveParallel401sTriggerOneRefresh() async throws {
        let server = StubServer()
        let tokens = InMemoryTokenStore(Session(accessToken: "old", refreshToken: "r1"))
        let api = client(server, tokens)
        try await withThrowingTaskGroup(of: Profile.self) { group in
            for i in 0..<5 { group.addTask { try await api.get("items/\(i)") } }
            for try await _ in group {}
        }
        #expect(server.count("/auth/refresh") == 1)
        #expect(tokens.load() == Session(accessToken: "new", refreshToken: "r2"))
    }

    @Test func rejectedRefreshClearsTheSession() async {
        let server = StubServer()
        server.refreshStatus = 401
        let tokens = InMemoryTokenStore(Session(accessToken: "old", refreshToken: "bad"))
        let expired = Flag()
        let api = client(server, tokens, onExpired: { expired.set() })
        await #expect(throws: AppError.unauthorized) { let _: Profile = try await api.get("me") }
        #expect(tokens.load() == nil)
        #expect(expired.value)
    }

    @Test func serverErrorDuringRefreshKeepsTheSession() async {
        let server = StubServer()
        server.refreshStatus = 503
        let tokens = InMemoryTokenStore(Session(accessToken: "old", refreshToken: "r1"))
        let api = client(server, tokens)
        await #expect(throws: (any Error).self) { let _: Profile = try await api.get("me") }
        #expect(tokens.load() != nil)
    }
}

final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = false
    var value: Bool { lock.withLock { _value } }
    func set() { lock.withLock { _value = true } }
}

@MainActor
@Suite struct SessionModelTests {
    @Test func restoresWithoutNetwork() {
        let server = StubServer()
        let model = SessionModel(tokens: InMemoryTokenStore(Session(accessToken: "a1", refreshToken: "r1")), http: server)
        model.restore()
        #expect(model.status == .signedIn)
        #expect(server.paths.isEmpty)
    }

    @Test func signInStoresTokensAndLoadsProfile() async throws {
        let tokens = InMemoryTokenStore()
        let model = SessionModel(tokens: tokens, http: StubServer())
        model.restore()
        #expect(model.status == .signedOut)
        try await model.signIn(username: "demo", password: "secret12")
        #expect(model.status == .signedIn)
        #expect(tokens.load()?.accessToken == "a1")
        #expect(try await model.profile().username == "demo")
    }

    @Test func wrongPasswordThrowsAndStaysSignedOut() async {
        let model = SessionModel(tokens: InMemoryTokenStore(), http: StubServer())
        model.restore()
        await #expect(throws: AppError.server(status: 400)) { try await model.signIn(username: "demo", password: "wrongpw") }
        #expect(model.status == .signedOut)
    }

    @Test func signOutClearsTokens() {
        let tokens = InMemoryTokenStore(Session(accessToken: "a1", refreshToken: "r1"))
        let model = SessionModel(tokens: tokens, http: StubServer())
        model.restore()
        model.signOut()
        #expect(model.status == .signedOut)
        #expect(tokens.load() == nil)
    }
}
