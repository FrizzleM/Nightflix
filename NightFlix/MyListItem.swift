import Foundation

enum MediaType: String, Codable, CaseIterable, Identifiable, Hashable {
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

    var watchType: WatchType {
        switch self {
        case .movie:
            return .movie
        case .tv:
            return .tv
        }
    }

    init?(tmdbValue: String) {
        switch tmdbValue {
        case "movie":
            self = .movie
        case "tv":
            self = .tv
        default:
            return nil
        }
    }
}

struct MyListItem: Identifiable, Codable, Equatable, Hashable {
    let mediaType: MediaType
    let tmdbId: Int
    let title: String
    let posterPath: String?
    let backdropPath: String?
    let overview: String?
    let year: String?
    let dateAdded: Date

    var id: String {
        "\(mediaType.rawValue)-\(tmdbId)"
    }

    var posterURL: URL? {
        imageURL(path: posterPath, baseURL: TMDBConfig.posterImageBaseURL)
    }

    var backdropURL: URL? {
        imageURL(path: backdropPath, baseURL: TMDBConfig.backdropImageBaseURL)
    }

    var mediaItem: MediaItem {
        MediaItem(
            id: tmdbId,
            mediaType: mediaType.rawValue,
            title: mediaType == .movie ? title : nil,
            name: mediaType == .tv ? title : nil,
            overview: overview ?? "",
            releaseDate: mediaType == .movie ? yearDate : nil,
            firstAirDate: mediaType == .tv ? yearDate : nil,
            posterPath: posterPath,
            backdropPath: backdropPath
        )
    }

    private var yearDate: String? {
        guard let year, !year.isEmpty else { return nil }
        return "\(year)-01-01"
    }

    private func imageURL(path: String?, baseURL: URL) -> URL? {
        guard let path else { return nil }
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        if let absoluteURL = URL(string: trimmedPath), absoluteURL.scheme != nil {
            return absoluteURL
        }

        return baseURL.appending(path: trimmedPath)
    }
}

extension MyListItem {
    init(movie: MovieDetail) {
        self.init(
            mediaType: .movie,
            tmdbId: movie.id,
            title: movie.title,
            posterPath: movie.posterPath,
            backdropPath: movie.backdropPath,
            overview: movie.overview,
            year: movie.releaseYear,
            dateAdded: Date()
        )
    }

    init(tv: TVSeriesDetail) {
        self.init(
            mediaType: .tv,
            tmdbId: tv.id,
            title: tv.name,
            posterPath: tv.posterPath,
            backdropPath: tv.backdropPath,
            overview: tv.overview,
            year: tv.firstAirYear,
            dateAdded: Date()
        )
    }
}
