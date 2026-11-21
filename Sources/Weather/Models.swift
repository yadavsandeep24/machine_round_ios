import Foundation

public struct City: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double

    public init(id: String, name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    public static let defaults: [City] = [
        City(id: "mum", name: "Mumbai", latitude: 19.07, longitude: 72.88),
        City(id: "del", name: "Delhi", latitude: 28.61, longitude: 77.21),
        City(id: "blr", name: "Bengaluru", latitude: 12.97, longitude: 77.59),
        City(id: "hyd", name: "Hyderabad", latitude: 17.39, longitude: 78.49),
        City(id: "che", name: "Chennai", latitude: 13.08, longitude: 80.27),
        City(id: "kol", name: "Kolkata", latitude: 22.57, longitude: 88.36),
        City(id: "pun", name: "Pune", latitude: 18.52, longitude: 73.86),
        City(id: "ahm", name: "Ahmedabad", latitude: 23.02, longitude: 72.57),
        City(id: "jai", name: "Jaipur", latitude: 26.91, longitude: 75.79),
        City(id: "lko", name: "Lucknow", latitude: 26.85, longitude: 80.95),
    ]
}

public struct Weather: Hashable, Sendable {
    public let temperatureC: Double
    public let windKmh: Double
    public let code: Int

    public init(temperatureC: Double, windKmh: Double, code: Int) {
        self.temperatureC = temperatureC
        self.windKmh = windKmh
        self.code = code
    }

    /// WMO weather interpretation codes (subset).
    public var condition: (text: String, symbol: String) {
        switch code {
        case 0: ("Clear", "sun.max")
        case 1, 2: ("Partly cloudy", "cloud.sun")
        case 3: ("Overcast", "cloud")
        case 45, 48: ("Fog", "cloud.fog")
        case 51...67, 80...82: ("Rain", "cloud.rain")
        case 71...77, 85, 86: ("Snow", "snowflake")
        case 95...99: ("Thunderstorm", "cloud.bolt.rain")
        default: ("Unknown", "questionmark")
        }
    }
}

public enum CitySort: String, CaseIterable, Sendable {
    case name = "Name"
    case warmest = "Warmest"
    case coldest = "Coldest"
}
