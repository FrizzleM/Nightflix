import Foundation

/// The kind of embed route the app should generate.
enum WatchType: String, Codable, CaseIterable, Identifiable, Hashable {
    case movie
    case tv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .movie:
            return "Movie"
        case .tv:
            return "TV Series"
        }
    }
}

/// A locally saved playback entry with the metadata needed for recent playback.
struct WatchItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: WatchType
    let title: String
    let tmdbId: String
    let season: Int?
    let episode: Int?
    let episodeName: String?
    let posterPath: String?
    let generatedURL: URL
    let dateWatched: Date

    init(
        id: UUID = UUID(),
        type: WatchType,
        title: String,
        tmdbId: String,
        season: Int? = nil,
        episode: Int? = nil,
        episodeName: String? = nil,
        posterPath: String? = nil,
        generatedURL: URL,
        dateWatched: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.tmdbId = tmdbId
        self.season = season
        self.episode = episode
        self.episodeName = episodeName
        self.posterPath = posterPath
        self.generatedURL = generatedURL
        self.dateWatched = dateWatched
    }

    var subtitle: String {
        switch type {
        case .movie:
            return "Watched \(dateWatched.formatted(date: .abbreviated, time: .shortened))"
        case .tv:
            let seasonText = season.map(String.init) ?? "-"
            let episodeText = episode.map(String.init) ?? "-"
            let episodeTitle = episodeName.map { " · \($0)" } ?? ""
            return "S\(seasonText) E\(episodeText)\(episodeTitle) · \(dateWatched.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case tmdbId
        case season
        case episode
        case episodeName
        case posterPath
        case generatedURL
        case dateWatched
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(WatchType.self, forKey: .type)
        tmdbId = try container.decode(String.self, forKey: .tmdbId)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        episode = try container.decodeIfPresent(Int.self, forKey: .episode)
        episodeName = try container.decodeIfPresent(String.self, forKey: .episodeName)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        generatedURL = try container.decode(URL.self, forKey: .generatedURL)
        dateWatched = try container.decode(Date.self, forKey: .dateWatched)

        if let decodedTitle = try container.decodeIfPresent(String.self, forKey: .title) {
            title = decodedTitle
        } else {
            title = type == .movie ? "Movie \(tmdbId)" : "TV \(tmdbId)"
        }
    }
}
