import Foundation
import Testing
@testable import Core

/// HTTP stub answering from a closure: no network, no URLProtocol registration.
struct StubHTTP: HTTPClient {
    let handler: @Sendable (URLRequest) throws -> (Int, Data)
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (status, data) = try handler(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct Item: Codable, Equatable, Sendable { let id: Int; let title: String }

@Suite struct APIClientTests {
    let base = URL(string: "https://api.test/")!

    @Test func decodesSuccessAndBuildsQuery() async throws {
        let client = APIClient(baseURL: base, http: StubHTTP { req in
            #expect(req.url?.absoluteString == "https://api.test/items?_limit=2&_page=1")
            return (200, Data(#"[{"id":1,"title":"a"}]"#.utf8))
        })
        let items: [Item] = try await client.get("items", query: ["_page": "1", "_limit": "2"])
        #expect(items == [Item(id: 1, title: "a")])
    }

    @Test(arguments: [(401, AppError.unauthorized), (404, .notFound), (500, .server(status: 500))])
    func mapsStatusCodes(status: Int, expected: AppError) async {
        let client = APIClient(baseURL: base, http: StubHTTP { _ in (status, Data()) })
        await #expect(throws: expected) { let _: [Item] = try await client.get("x") }
    }

    @Test func mapsBadJsonToDecoding() async {
        let client = APIClient(baseURL: base, http: StubHTTP { _ in (200, Data("{bad".utf8)) })
        do {
            let _: [Item] = try await client.get("x")
            Issue.record("expected failure")
        } catch {
            if case .decoding = error {} else { Issue.record("got \(error)") }
        }
    }

    @Test func mapsTransportErrors() {
        #expect(AppError.map(URLError(.notConnectedToInternet)) == .noInternet)
        #expect(AppError.map(URLError(.timedOut)) == .timeout)
        #expect(AppError.map(CancellationError()) == .cancelled)
        #expect(AppError.map(URLError(.cancelled)).isCancellation)
    }

    @Test func storeTreatsCorruptDataAsMissing() {
        let store = InMemoryStore(["k": Data("nope".utf8)])
        #expect(store.value([Item].self, forKey: "k") == nil)
        store.setValue([Item(id: 2, title: "b")], forKey: "k")
        #expect(store.value([Item].self, forKey: "k") == [Item(id: 2, title: "b")])
    }
}
