import Core
import Testing
@testable import Posts

@MainActor
@Suite struct FavoritesTests {
    @Test func togglePersistsAcrossRelaunch() {
        let store = InMemoryStore()
        let favorites = FavoritesStore(store: store)
        favorites.toggle(3)
        favorites.toggle(5)
        favorites.toggle(3)
        #expect(favorites.ids == [5])
        #expect(FavoritesStore(store: store).ids == [5]) // a fresh instance = relaunch
    }
}
