import Foundation
import Observation

/// Handles simple local persistence for recently watched items.
@Observable
final class WatchHistoryManager {
    private(set) var items: [WatchItem] = []

    private let storageKey = "recentlyWatchedItems"
    private let maxItems = 12
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        load()
    }

    func add(_ item: WatchItem) {
        items.removeAll { existingItem in
            existingItem.type == item.type
                && existingItem.tmdbId == item.tmdbId
                && existingItem.season == item.season
                && existingItem.episode == item.episode
        }

        items.insert(item, at: 0)
        items = Array(items.prefix(maxItems))
        save()
    }

    func clear() {
        items = []
        userDefaults.removeObject(forKey: storageKey)
    }

    private func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([WatchItem].self, from: data)
        } catch {
            items = []
        }
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
