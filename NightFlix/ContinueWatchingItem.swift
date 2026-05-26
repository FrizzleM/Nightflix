import Foundation

/// A deduplicated movie or series entry for the Continue Watching rail.
struct ContinueWatchingItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: WatchType
    let title: String
    let tmdbId: String
    let posterPath: String?
    let playableURL: URL?
    let lastWatchedDate: Date

    init(
        id: UUID = UUID(),
        type: WatchType,
        title: String,
        tmdbId: String,
        posterPath: String? = nil,
        playableURL: URL? = nil,
        lastWatchedDate: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.tmdbId = tmdbId
        self.posterPath = posterPath
        self.playableURL = playableURL
        self.lastWatchedDate = lastWatchedDate
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        let trimmedPath = posterPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        if let absoluteURL = URL(string: trimmedPath), absoluteURL.scheme != nil {
            return absoluteURL
        }

        return TMDBConfig.imageBaseURL.appending(path: trimmedPath)
    }

    var tmdbIntId: Int? {
        Int(tmdbId)
    }
}
