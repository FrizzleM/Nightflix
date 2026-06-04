import Foundation
import Observation

/// Handles local persistence for the deduplicated Continue Watching rail.
@Observable
final class ContinueWatchingManager {
    private(set) var items: [ContinueWatchingItem] = []

    private let storageKey = "continueWatchingItems"
    private let maxItems = 20
    private let userDefaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func addOrUpdate(item: ContinueWatchingItem) {
        items.removeAll { existingItem in
            existingItem.type == item.type && existingItem.tmdbId == item.tmdbId
        }

        items.insert(item, at: 0)
        normalizeItems()
        save()
    }

    func clear() {
        items = []
        userDefaults.removeObject(forKey: storageKey)
    }

    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            let decodedItems = try decoder.decode([ContinueWatchingItem].self, from: data)
            let normalizedItems = normalizedItems(decodedItems)

            items = normalizedItems

            if normalizedItems != decodedItems {
                save()
            }
        } catch {
            items = []
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    private func normalizeItems() {
        items = normalizedItems(items)
    }

    private func normalizedItems(_ sourceItems: [ContinueWatchingItem]) -> [ContinueWatchingItem] {
        var seenKeys = Set<String>()

        let normalizedItems = sourceItems
            .sorted { $0.lastWatchedDate > $1.lastWatchedDate }
            .filter { item in
                let key = "\(item.type.rawValue)-\(item.tmdbId)"
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
            }

        return Array(normalizedItems.prefix(maxItems))
    }

    private func save() {
        do {
            let data = try encoder.encode(items)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            userDefaults.removeObject(forKey: storageKey)
        }
    }
}
