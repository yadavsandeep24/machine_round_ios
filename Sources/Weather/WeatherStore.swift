import Core
import Observation

/// ONE source of truth shared by the Cities tab, the Favourites tab and the
/// detail screen. That is what keeps the favourite button in sync across
/// screens: nobody holds a copy, everybody reads this store.
@MainActor
@Observable
public final class WeatherStore {
    public private(set) var cities: [City]
    public private(set) var weather: [String: Weather] = [:]
    public private(set) var status: Loadable<Void> = .idle
    public private(set) var favouriteIds: Set<String>
    public var sort: CitySort = .name

    @ObservationIgnored private let service: any WeatherService
    @ObservationIgnored private let store: any KeyValueStore
    private static let favouritesKey = "favourite_city_ids_v1"

    public init(cities: [City] = City.defaults, service: any WeatherService, store: any KeyValueStore) {
        self.cities = cities
        self.service = service
        self.store = store
        favouriteIds = store.value(Set<String>.self, forKey: Self.favouritesKey) ?? []
    }

    /// Sorted once per read of the inputs; cities without data sort last.
    public var sortedCities: [City] {
        switch sort {
        case .name:
            return cities.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .warmest, .coldest:
            return cities.sorted { a, b in
                switch (weather[a.id]?.temperatureC, weather[b.id]?.temperatureC) {
                case let (x?, y?): return sort == .warmest ? x > y : x < y
                case (.some, nil): return true
                case (nil, .some): return false
                case (nil, nil): return a.name < b.name
                }
            }
        }
    }

    public var favouriteCities: [City] { sortedCities.filter { favouriteIds.contains($0.id) } }

    public func isFavourite(_ city: City) -> Bool { favouriteIds.contains(city.id) }

    public func toggleFavourite(_ city: City) {
        if favouriteIds.remove(city.id) == nil { favouriteIds.insert(city.id) }
        store.setValue(favouriteIds, forKey: Self.favouritesKey)
    }

    public func load() async {
        if status.isLoading { return }
        status = .loading(previous: nil)
        do {
            weather = try await service.current(for: cities)
            status = .loaded(())
        } catch where error.isCancellation {
            status = .idle
        } catch {
            status = .failed(error, previous: weather.isEmpty ? nil : ())
        }
    }
}
