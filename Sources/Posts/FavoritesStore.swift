import Core
import Observation
import SwiftUI

/// App-wide favorites shared by the list, search results and detail screens.
/// Injected once with `.environment(favorites)`, so every screen sees the same
/// instance. Persisted in the KeyValueStore.
@MainActor
@Observable
public final class FavoritesStore {
    public private(set) var ids: Set<Int>
    @ObservationIgnored private let store: any KeyValueStore
    private static let key = "favorite_ids_v1"

    public init(store: any KeyValueStore) {
        self.store = store
        ids = store.value(Set<Int>.self, forKey: Self.key) ?? []
    }

    public func contains(_ id: Int) -> Bool { ids.contains(id) }

    public func toggle(_ id: Int) {
        if ids.remove(id) == nil { ids.insert(id) }
        store.setValue(ids, forKey: Self.key)
    }
}

public struct FavoriteButton: View {
    @Environment(FavoritesStore.self) private var favorites
    let id: Int

    public init(id: Int) { self.id = id }

    public var body: some View {
        let isFavorite = favorites.contains(id)
        Button {
            favorites.toggle(id)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? .red : .secondary)
        }
        .buttonStyle(.borderless) // tappable inside a List row without opening the row
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}
