import Core
import SwiftUI

/// Two tabs + detail, all reading the same `WeatherStore` from the environment.
public struct WeatherRootView: View {
    @State private var store: WeatherStore

    public init(store: WeatherStore) { _store = State(initialValue: store) }

    public var body: some View {
        TabView {
            NavigationStack { CityListView(mode: .all) }
                .tabItem { Label("Cities", systemImage: "list.bullet") }
            NavigationStack { CityListView(mode: .favourites) }
                .tabItem { Label("Favourites", systemImage: "star") }
                .badge(store.favouriteIds.count)
        }
        .environment(store)
        .task { await store.load() }
    }
}

struct CityListView: View {
    enum Mode { case all, favourites }
    let mode: Mode
    @Environment(WeatherStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let cities = mode == .all ? store.sortedCities : store.favouriteCities
        Group {
            if case .failed(let error, nil) = store.status {
                ErrorView(message: error.userMessage) { Task { await store.load() } }
            } else if store.weather.isEmpty && store.status.isLoading {
                LoadingView()
            } else if cities.isEmpty {
                EmptyStateView(mode == .favourites ? "No favourites yet. Tap ☆ on a city." : "No cities", systemImage: "star")
            } else {
                List(cities) { city in
                    NavigationLink(value: city) { CityRow(city: city) }
                }
                .refreshable { await store.load() }
            }
        }
        .navigationTitle(mode == .all ? "Weather" : "Favourites")
        .toolbar {
            Picker("Sort", selection: $store.sort) {
                ForEach(CitySort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        .navigationDestination(for: City.self) { CityDetailView(city: $0) }
    }
}

struct CityRow: View {
    let city: City
    @Environment(WeatherStore.self) private var store

    var body: some View {
        HStack {
            if let w = store.weather[city.id] {
                Image(systemName: w.condition.symbol).frame(width: 28)
            }
            Text(city.name)
            Spacer()
            if let w = store.weather[city.id] {
                Text(w.temperatureC, format: .number.precision(.fractionLength(0))).monospacedDigit() + Text("°")
            }
            FavouriteButton(city: city)
        }
    }
}

struct FavouriteButton: View {
    let city: City
    @Environment(WeatherStore.self) private var store

    var body: some View {
        let on = store.isFavourite(city)
        Button { store.toggleFavourite(city) } label: {
            Image(systemName: on ? "star.fill" : "star").foregroundStyle(on ? .yellow : .secondary)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(on ? "Remove \(city.name) from favourites" : "Add \(city.name) to favourites")
    }
}

struct CityDetailView: View {
    let city: City
    @Environment(WeatherStore.self) private var store

    var body: some View {
        VStack(spacing: 16) {
            if let w = store.weather[city.id] {
                Image(systemName: w.condition.symbol).font(.system(size: 64))
                Text("\(Int(w.temperatureC.rounded()))°C").font(.largeTitle.bold())
                Text(w.condition.text)
                Text("Wind \(Int(w.windKmh.rounded())) km/h").foregroundStyle(.secondary)
            } else {
                Text("No data yet")
            }
        }
        .navigationTitle(city.name)
        .toolbar { FavouriteButton(city: city) }
    }
}
