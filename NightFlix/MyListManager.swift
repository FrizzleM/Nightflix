import Combine
import Foundation

final class MyListManager: ObservableObject {
    @Published private(set) var items: [MyListItem] = []

    private let storageKey = "myListItems"
    private let userDefaults: UserDefaults

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
        items.removeAll { item in
            item.mediaType == mediaType && item.tmdbId == tmdbId
        }
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
        items.contains { item in
            item.mediaType == mediaType && item.tmdbId == tmdbId
        }
    }

    func load() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            items = []
            return
        }

        do {
            items = try JSONDecoder().decode([MyListItem].self, from: data)
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
            .sorted { $0.dateAdded > $1.dateAdded }
            .filter { item in
                let key = "\(item.mediaType.rawValue)-\(item.tmdbId)"
                guard !seenKeys.contains(key) else { return false }
                seenKeys.insert(key)
                return true
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
