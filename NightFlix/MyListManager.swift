import Combine
import Foundation

final class MyListManager: ObservableObject {
    @Published private(set) var items: [MyListItem] = []

    private let storageKey = "myListItems"
    private let userDefaults: UserDefaults
    private var itemKeys: Set<String> = []

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func add(_ item: MyListItem) {
        items.removeAll { existingItem in
            existingItem.mediaType == item.mediaType && existingItem.tmdbId == item.tmdbId
        }

        items.insert(item, at: 0)
        normalizeItems()
        save()
    }

    func remove(mediaType: MediaType, tmdbId: Int) {
        let originalCount = items.count
        items.removeAll { item in
            item.mediaType == mediaType && item.tmdbId == tmdbId
        }
        guard items.count != originalCount else { return }

        rebuildItemKeys()
        save()
    }

    func toggle(_ item: MyListItem) {
        if contains(mediaType: item.mediaType, tmdbId: item.tmdbId) {
            remove(mediaType: item.mediaType, tmdbId: item.tmdbId)
        } else {
            add(item)
        }
    }

    func contains(mediaType: MediaType, tmdbId: Int) -> Bool {
        itemKeys.contains(Self.key(mediaType: mediaType, tmdbId: tmdbId))
    }

    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            items = []
            itemKeys = []
            return
        }

        do {
            let decodedItems = try JSONDecoder().decode([MyListItem].self, from: data)
            let normalizedItems = normalizedItems(decodedItems)

            items = normalizedItems
            rebuildItemKeys()

            if normalizedItems != decodedItems {
                save()
            }
        } catch {
            items = []
            itemKeys = []
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    private func normalizeItems() {
        items = normalizedItems(items)
        rebuildItemKeys()
    }

    private func normalizedItems(_ sourceItems: [MyListItem]) -> [MyListItem] {
        var seenKeys = Set<String>()

        return sourceItems
            .sorted { $0.dateAdded > $1.dateAdded }
            .filter { item in
                let key = Self.key(for: item)
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
            }
    }

    private func rebuildItemKeys() {
        itemKeys = Set(items.map(Self.key(for:)))
    }

    nonisolated private static func key(for item: MyListItem) -> String {
        key(mediaType: item.mediaType, tmdbId: item.tmdbId)
    }

    nonisolated private static func key(mediaType: MediaType, tmdbId: Int) -> String {
        "\(mediaType.rawValue)-\(tmdbId)"
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
}
