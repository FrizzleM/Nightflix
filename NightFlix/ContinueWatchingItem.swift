import Foundation

/// A deduplicated movie or series entry for the Continue Watching rail.
struct ContinueWatchingItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: WatchType
    let title: String
    let tmdbId: String
    let season: Int?
    let episode: Int?
    let episodeName: String?
    let posterPath: String?
    let playableURL: URL?
    let lastWatchedDate: Date
    /// Resume position in seconds (nil before any progress is reported).
    let progressSeconds: Double?
    /// Total duration in seconds, when known.
    let durationSeconds: Double?

    init(
        id: UUID = UUID(),
        type: WatchType,
        title: String,
        tmdbId: String,
        season: Int? = nil,
        episode: Int? = nil,
        episodeName: String? = nil,
        posterPath: String? = nil,
        playableURL: URL? = nil,
        lastWatchedDate: Date = Date(),
        progressSeconds: Double? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.tmdbId = tmdbId
        self.season = season
        self.episode = episode
        self.episodeName = episodeName
        self.posterPath = posterPath
        self.playableURL = playableURL
        self.lastWatchedDate = lastWatchedDate
        self.progressSeconds = progressSeconds
        self.durationSeconds = durationSeconds
    }

    /// Fraction watched in `0...1`, or `nil` when there isn't enough info to show a bar.
    var progressFraction: Double? {
        guard let progressSeconds, let durationSeconds, durationSeconds > 0 else { return nil }
        return min(max(progressSeconds / durationSeconds, 0), 1)
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
