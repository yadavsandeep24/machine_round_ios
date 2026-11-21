import Core
import Foundation
import Testing
@testable import Weather

final class FakeWeatherService: WeatherService, @unchecked Sendable {
    var result: [String: Weather] = [:]
    var failWith: AppError?
    private(set) var calls = 0
    func current(for cities: [City]) async throws(AppError) -> [String: Weather] {
        calls += 1
        if let failWith { throw failWith }
        return result
    }
}

let three = Array(City.defaults.prefix(3)) // Mumbai, Delhi, Bengaluru
func w(_ t: Double) -> Weather { Weather(temperatureC: t, windKmh: 5, code: 0) }

@MainActor
@Suite struct WeatherStoreTests {
    func makeStore(_ kv: InMemoryStore = InMemoryStore()) -> (WeatherStore, FakeWeatherService) {
        let service = FakeWeatherService()
        service.result = ["mum": w(30), "del": w(18), "blr": w(24)]
        return (WeatherStore(cities: three, service: service, store: kv), service)
    }

    @Test func sortsByNameAndTemperature() async {
        let (store, _) = makeStore()
        await store.load()
        #expect(store.sortedCities.map(\.name) == ["Bengaluru", "Delhi", "Mumbai"])
        store.sort = .warmest
        #expect(store.sortedCities.map(\.id) == ["mum", "blr", "del"])
        store.sort = .coldest
        #expect(store.sortedCities.map(\.id) == ["del", "blr", "mum"])
    }

    @Test func favouriteIsTheSameEverywhereAndPersists() async {
        let kv = InMemoryStore()
        let (store, _) = makeStore(kv)
        let delhi = three[1]
        store.toggleFavourite(delhi) // tapped on the Cities tab
        #expect(store.favouriteCities.map(\.id) == ["del"]) // Favourites tab sees it
        #expect(store.isFavourite(delhi)) // detail screen sees it
        store.toggleFavourite(delhi) // un-starred from the detail screen
        #expect(store.favouriteCities.isEmpty)
        store.toggleFavourite(three[0])
        #expect(WeatherStore(cities: three, service: FakeWeatherService(), store: kv).favouriteIds == ["mum"])
    }

    @Test func failureWithoutDataIsAnErrorAndRetryWorks() async {
        let (store, service) = makeStore()
        service.failWith = .noInternet
        await store.load()
        #expect(store.status.error == .noInternet)
        service.failWith = nil
        await store.load()
        #expect(store.weather.count == 3)
    }
}

@Suite struct OpenMeteoServiceTests {
    struct Stub: HTTPClient {
        let body: String
        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
    static let item = #"{"current":{"temperature_2m":24.1,"weather_code":3,"wind_speed_10m":5.4}}"#

    @Test func decodesManyCitiesFromOneArrayResponse() async throws {
        let api = APIClient(baseURL: URL(string: "https://x.test/")!, http: Stub(body: "[\(Self.item),\(Self.item)]"))
        let result = try await OpenMeteoService(api: api).current(for: Array(City.defaults.prefix(2)))
        #expect(result["mum"] == Weather(temperatureC: 24.1, windKmh: 5.4, code: 3))
        #expect(result["del"]?.condition.text == "Overcast")
    }

    @Test func decodesASingleCityObjectResponse() async throws {
        let api = APIClient(baseURL: URL(string: "https://x.test/")!, http: Stub(body: Self.item))
        let result = try await OpenMeteoService(api: api).current(for: [City.defaults[0]])
        #expect(result.count == 1)
    }
}

@Suite struct ClosureCaptureTests {
    @Test func strongCaptureLeaksWeakCaptureDoesNot() {
        weak var leaky: LeakyWeatherController?
        weak var safe: SafeWeatherController?
        do {
            let a = LeakyWeatherController(); a.tick(); leaky = a
            let b = SafeWeatherController(); b.tick(); safe = b
            #expect(a.refreshes == 1 && b.refreshes == 1)
        }
        #expect(leaky != nil) // still alive: retain cycle
        #expect(safe == nil) // freed
    }
}
