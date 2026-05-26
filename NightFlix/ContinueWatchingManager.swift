import Foundation
import Observation

/// Handles local persistence for the deduplicated Continue Watching rail.
@Observable
final class ContinueWatchingManager {
    private(set) var items: [ContinueWatchingItem] = []

    private let storageKey = "continueWatchingItems"
    private let maxItems = 20
    private let userDefaults: UserDefaults

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
            items = try JSONDecoder().decode([ContinueWatchingItem].self, from: data)
            normalizeItems()
            save()
        } catch {
            items = []
            userDefaults.removeObject(forKey: storageKey)
        }
    }

    private func normalizeItems() {
        var seenKeys = Set<String>()
        items = items
            .sorted { $0.lastWatchedDate > $1.lastWatchedDate }
            .filter { item in
                let key = "\(item.type.rawValue)-\(item.tmdbId)"
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
            }
        items = Array(items.prefix(maxItems))
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
