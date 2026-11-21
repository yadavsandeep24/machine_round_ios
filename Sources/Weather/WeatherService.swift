import Core
import Foundation

public protocol WeatherService: Sendable {
    /// Current weather for many cities in ONE request (Open-Meteo accepts
    /// comma-separated coordinates), keyed by city id.
    func current(for cities: [City]) async throws(AppError) -> [String: Weather]
}

public struct OpenMeteoService: WeatherService {
    private let api: APIClient

    public init(api: APIClient = APIClient(baseURL: URL(string: "https://api.open-meteo.com/v1/")!)) {
        self.api = api
    }

    struct Response: Decodable, Sendable {
        struct Current: Decodable, Sendable {
            let temperature2m: Double
            let weatherCode: Int
            let windSpeed10m: Double
            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
                case windSpeed10m = "wind_speed_10m"
            }
        }
        let current: Current
    }

    public func current(for cities: [City]) async throws(AppError) -> [String: Weather] {
        guard !cities.isEmpty else { return [:] }
        let query = [
            "latitude": cities.map { String($0.latitude) }.joined(separator: ","),
            "longitude": cities.map { String($0.longitude) }.joined(separator: ","),
            "current": "temperature_2m,weather_code,wind_speed_10m",
        ]
        // One location returns an object, several return an array.
        let responses: [Response]
        if cities.count == 1 {
            responses = [try await api.get("forecast", query: query, as: Response.self)]
        } else {
            responses = try await api.get("forecast", query: query, as: [Response].self)
        }
        guard responses.count == cities.count else { throw .decoding("Expected \(cities.count) results") }
        return Dictionary(uniqueKeysWithValues: zip(cities, responses).map { city, r in
            (city.id, Weather(temperatureC: r.current.temperature2m, windKmh: r.current.windSpeed10m, code: r.current.weatherCode))
        })
    }
}
