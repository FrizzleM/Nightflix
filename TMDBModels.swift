import Foundation

struct TMDBSearchResponse<Result: Decodable>: Decodable {
    let results: [Result]

    enum CodingKeys: String, CodingKey {
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeLossyArray(Result.self, forKey: .results)
    }
}

private struct FailableDecodable<Base: Decodable>: Decodable {
    let value: Base?

    init(from decoder: Decoder) throws {
        value = try? Base(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyArray<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> [Value] {
        let values = try decodeIfPresent([FailableDecodable<Value>].self, forKey: key)
        return values?.compactMap(\.value) ?? []
    }
}

struct TMDBMovieResult: Identifiable, Decodable, Equatable {
    let id: Int
    let title: String
    let releaseDate: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Movie"
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    }

    var releaseYear: String? {
        releaseDate?.prefix(4).description
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct TMDBTVResult: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let firstAirDate: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case firstAirDate = "first_air_date"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled Series"
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    }

    var firstAirYear: String? {
        firstAirDate?.prefix(4).description
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct MediaSearchResult: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let releaseDate: String?
    let firstAirDate: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    }

    var displayTitle: String {
        if isMovie {
            return title ?? "Untitled Movie"
        }

        return name ?? "Untitled Series"
    }

    var displayYear: String? {
        if isMovie {
            return releaseDate?.prefix(4).description
        }

        return firstAirDate?.prefix(4).description
    }

    var isMovie: Bool {
        mediaType == "movie"
    }

    var isTVSeries: Bool {
        mediaType == "tv"
    }

    var type: WatchType {
        isMovie ? .movie : .tv
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct MediaItem: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let overview: String
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    init(
        id: Int,
        mediaType: String,
        title: String?,
        name: String?,
        overview: String = "",
        releaseDate: String? = nil,
        firstAirDate: String? = nil,
        posterPath: String? = nil,
        backdropPath: String? = nil
    ) {
        self.id = id
        self.mediaType = mediaType
        self.title = title
        self.name = name
        self.overview = overview
        self.releaseDate = releaseDate
        self.firstAirDate = firstAirDate
        self.posterPath = posterPath
        self.backdropPath = backdropPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    }

    var displayTitle: String {
        if isMovie {
            return title ?? "Untitled Movie"
        }

        return name ?? "Untitled Series"
    }

    var displayYear: String? {
        if isMovie {
            return releaseDate?.prefix(4).description
        }

        return firstAirDate?.prefix(4).description
    }

    var isMovie: Bool {
        mediaType == "movie"
    }

    var isTVSeries: Bool {
        mediaType == "tv"
    }

    var type: WatchType {
        isMovie ? .movie : .tv
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.posterImageBaseURL.appending(path: posterPath)
    }

    var backdropURL: URL? {
        guard let backdropPath else { return nil }
        return TMDBConfig.backdropImageBaseURL.appending(path: backdropPath)
    }
}

struct TVSeriesDetails: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let overview: String
    let posterPath: String?
    let firstAirDate: String?
    let seasons: [Season]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case overview
        case posterPath = "poster_path"
        case firstAirDate = "first_air_date"
        case seasons
    }

    var firstAirYear: String? {
        firstAirDate?.prefix(4).description
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct Season: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodeCount: Int
    let posterPath: String?
    let airDate: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
        case posterPath = "poster_path"
        case airDate = "air_date"
        case overview
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct SeasonDetails: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let episodes: [Episode]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case seasonNumber = "season_number"
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Season"
        seasonNumber = try container.decode(Int.self, forKey: .seasonNumber)
        episodes = try container.decodeLossyArray(Episode.self, forKey: .episodes)
    }
}

struct Episode: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int
    let overview: String
    let stillPath: String?
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case overview
        case stillPath = "still_path"
        case airDate = "air_date"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Episode"
        episodeNumber = try container.decode(Int.self, forKey: .episodeNumber)
        seasonNumber = try container.decode(Int.self, forKey: .seasonNumber)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        stillPath = try container.decodeIfPresent(String.self, forKey: .stillPath)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
    }

    var stillURL: URL? {
        guard let stillPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: stillPath)
    }
}

struct SeriesSelection: Identifiable, Hashable {
    let id: Int
    let name: String
    let posterPath: String?
}

struct TMDBTrendingResult: Identifiable, Decodable, Equatable {
    let id: Int
    let mediaType: String
    let title: String?
    let name: String?
    let releaseDate: String?
    let firstAirDate: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case mediaType = "media_type"
        case title
        case name
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        mediaType = try container.decode(String.self, forKey: .mediaType)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try container.decodeIfPresent(String.self, forKey: .backdropPath)
    }
}

struct FeedItem: Identifiable, Equatable, Hashable {
    let id: Int
    let type: WatchType
    let title: String
    let year: String?
    let overview: String
    let posterPath: String?
    let backdropPath: String?

    init(movie: TMDBMovieResult) {
        id = movie.id
        type = .movie
        title = movie.title
        year = movie.releaseYear
        overview = movie.overview
        posterPath = movie.posterPath
        backdropPath = movie.backdropPath
    }

    init(tv: TMDBTVResult) {
        id = tv.id
        type = .tv
        title = tv.name
        year = tv.firstAirYear
        overview = tv.overview
        posterPath = tv.posterPath
        backdropPath = tv.backdropPath
    }

    init(recommendation: MediaRecommendationItem, fallbackType: WatchType) {
        let resolvedType: WatchType
        switch recommendation.mediaType {
        case "movie":
            resolvedType = .movie
        case "tv":
            resolvedType = .tv
        default:
            resolvedType = fallbackType
        }

        id = recommendation.id
        type = resolvedType
        title = recommendation.displayTitle
        year = recommendation.displayYear
        overview = recommendation.overview ?? ""
        posterPath = recommendation.posterPath
        backdropPath = recommendation.backdropPath
    }

    init?(trendingResult: TMDBTrendingResult) {
        switch trendingResult.mediaType {
        case "movie":
            type = .movie
            title = trendingResult.title ?? "Untitled Movie"
            year = trendingResult.releaseDate?.prefix(4).description
        case "tv":
            type = .tv
            title = trendingResult.name ?? "Untitled Series"
            year = trendingResult.firstAirDate?.prefix(4).description
        default:
            return nil
        }

        id = trendingResult.id
        overview = trendingResult.overview
        posterPath = trendingResult.posterPath
        backdropPath = trendingResult.backdropPath
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }
}

struct Genre: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
}

struct CastMember: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case character
        case profilePath = "profile_path"
        case order
    }

    var profileURL: URL? {
        guard let profilePath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w185\(profilePath)")
    }
}

struct CrewMember: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case job
        case department
        case profilePath = "profile_path"
    }
}

struct VideoResult: Identifiable, Decodable, Equatable, Hashable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?

    var youtubeURL: URL? {
        guard site.caseInsensitiveCompare("YouTube") == .orderedSame else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

struct MediaRecommendationItem: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let mediaType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case overview
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case mediaType = "media_type"
    }

    var displayTitle: String {
        title ?? name ?? "Untitled"
    }

    var displayYear: String? {
        (releaseDate ?? firstAirDate)?.prefix(4).description
    }

    var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.posterImageBaseURL.appending(path: posterPath)
    }
}

struct TMDBListResponse<Result: Decodable & Equatable>: Decodable, Equatable {
    let results: [Result]

    enum CodingKeys: String, CodingKey {
        case results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeLossyArray(Result.self, forKey: .results)
    }
}

struct Credits: Decodable, Equatable {
    let cast: [CastMember]
    let crew: [CrewMember]?
}

struct Videos: Decodable, Equatable {
    let results: [VideoResult]
}

struct MovieDetail: Identifiable, Decodable, Equatable {
    let id: Int
    let title: String
    let tagline: String?
    let overview: String
    let releaseDate: String?
    let runtime: Int?
    let genres: [Genre]
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let backdropPath: String?
    let credits: Credits?
    let videos: Videos?
    let similar: TMDBListResponse<MediaRecommendationItem>?
    let recommendations: TMDBListResponse<MediaRecommendationItem>?
    let releaseDates: TMDBListResponse<MovieReleaseDatesResult>?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case tagline
        case overview
        case releaseDate = "release_date"
        case runtime
        case genres
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case credits
        case videos
        case similar
        case recommendations
        case releaseDates = "release_dates"
    }

    var releaseYear: String? {
        releaseDate?.prefix(4).description
    }
}

struct TVSeriesDetail: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let tagline: String?
    let overview: String
    let firstAirDate: String?
    let lastAirDate: String?
    let numberOfSeasons: Int
    let numberOfEpisodes: Int
    let status: String?
    let genres: [Genre]
    let voteAverage: Double
    let voteCount: Int
    let posterPath: String?
    let backdropPath: String?
    let createdBy: [Creator]
    let seasons: [Season]
    let credits: Credits?
    let videos: Videos?
    let similar: TMDBListResponse<MediaRecommendationItem>?
    let recommendations: TMDBListResponse<MediaRecommendationItem>?
    let contentRatings: TMDBListResponse<TVContentRating>?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagline
        case overview
        case firstAirDate = "first_air_date"
        case lastAirDate = "last_air_date"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case status
        case genres
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case createdBy = "created_by"
        case seasons
        case credits
        case videos
        case similar
        case recommendations
        case contentRatings = "content_ratings"
    }

    var firstAirYear: String? {
        firstAirDate?.prefix(4).description
    }

    var lastAirYear: String? {
        lastAirDate?.prefix(4).description
    }
}

struct Creator: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
}

struct SeasonDetail: Identifiable, Decodable, Equatable {
    let id: Int
    let name: String
    let seasonNumber: Int
    let overview: String?
    let posterPath: String?
    let airDate: String?
    let episodes: [EpisodeDetail]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case seasonNumber = "season_number"
        case overview
        case posterPath = "poster_path"
        case airDate = "air_date"
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Season"
        seasonNumber = try container.decode(Int.self, forKey: .seasonNumber)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        posterPath = try container.decodeIfPresent(String.self, forKey: .posterPath)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
        episodes = try container.decodeLossyArray(EpisodeDetail.self, forKey: .episodes)
    }
}

struct EpisodeDetail: Identifiable, Decodable, Equatable, Hashable {
    let id: Int
    let name: String
    let episodeNumber: Int
    let seasonNumber: Int
    let overview: String
    let stillPath: String?
    let airDate: String?
    let runtime: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case overview
        case stillPath = "still_path"
        case airDate = "air_date"
        case runtime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Episode"
        episodeNumber = try container.decode(Int.self, forKey: .episodeNumber)
        seasonNumber = try container.decode(Int.self, forKey: .seasonNumber)
        overview = try container.decodeIfPresent(String.self, forKey: .overview) ?? ""
        stillPath = try container.decodeIfPresent(String.self, forKey: .stillPath)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
    }

    var stillURL: URL? {
        guard let stillPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(stillPath)")
    }
}

struct MovieReleaseDatesResult: Decodable, Equatable {
    let iso31661: String?

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
    }
}

struct TVContentRating: Decodable, Equatable {
    let iso31661: String?
    let rating: String?

    enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case rating
    }
}
