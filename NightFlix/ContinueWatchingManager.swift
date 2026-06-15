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

    /// Merges a fresh playback position into the matching entry (by type + tmdbId),
    /// preserving artwork/title and advancing the tracked season/episode. Creates the
    /// entry if it doesn't exist yet.
    func recordProgress(
        type: WatchType,
        tmdbId: String,
        title: String,
        posterPath: String?,
        season: Int?,
        episode: Int?,
        episodeName: String?,
        positionSeconds: Double,
        durationSeconds: Double
    ) {
        let existing = items.first { $0.type == type && $0.tmdbId == tmdbId }
        let isSameEpisode = existing?.season == season && existing?.episode == episode
        let resolvedEpisodeName = isSameEpisode ? (episodeName ?? existing?.episodeName) : episodeName
        let resolvedPoster = posterPath ?? existing?.posterPath
        let resolvedDuration = durationSeconds > 0 ? durationSeconds : existing?.durationSeconds

        addOrUpdate(
            item: ContinueWatchingItem(
                type: type,
                title: title,
                tmdbId: tmdbId,
                season: season,
                episode: episode,
                episodeName: resolvedEpisodeName,
                posterPath: resolvedPoster,
                playableURL: existing?.playableURL,
                progressSeconds: positionSeconds,
                durationSeconds: resolvedDuration
            )
        )
    }

    /// Removes a title from the rail once it has been watched to completion.
    func markFinished(type: WatchType, tmdbId: String) {
        let originalCount = items.count
        items.removeAll { $0.type == type && $0.tmdbId == tmdbId }
        guard items.count != originalCount else { return }
        save()
    }

    /// The saved resume position (seconds) for an exact movie/episode, or `nil` when
    /// there isn't a meaningful position to resume from.
    func resumeSeconds(type: WatchType, tmdbId: String, season: Int?, episode: Int?) -> Int? {
        guard let item = items.first(where: { $0.type == type && $0.tmdbId == tmdbId }) else {
            return nil
        }

        if type == .tv {
            guard item.season == season, item.episode == episode else { return nil }
        }

        guard let position = item.progressSeconds, position >= 5 else { return nil }
        if let fraction = item.progressFraction, fraction >= 0.95 { return nil }

        return Int(position)
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
