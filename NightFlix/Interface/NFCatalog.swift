import Foundation
import Observation
import UserNotifications

// MARK: - Payloads

/// Decodes a field to `nil` (or drops an element) instead of failing the whole response.
struct NFLossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// The fields shared by every TMDB list result.
protocol NFTitleFields {
    var id: Int { get }
    var mediaType: String? { get }
    var title: String? { get }
    var name: String? { get }
    var overview: String? { get }
    var releaseDate: String? { get }
    var firstAirDate: String? { get }
    var posterPath: String? { get }
    var backdropPath: String? { get }
    var voteAverage: Double? { get }
    var voteCount: Int? { get }
    var genreIds: [Int]? { get }
}

extension NFTitleFields {
    /// Resolves to a `MediaItem`, using `fallback` when the list doesn't say whether it
    /// holds movies or series (e.g. `/movie/popular`). People and unknowns return nil.
    func mediaItem(fallback: WatchType?) -> MediaItem? {
        let type: WatchType
        switch mediaType {
        case "movie": type = .movie
        case "tv": type = .tv
        case nil:
            guard let fallback else { return nil }
            type = fallback
        default:
            return nil
        }

        return MediaItem(
            id: id,
            mediaType: type.tmdbPath,
            title: type == .movie ? (title ?? name) : nil,
            name: type == .tv ? (name ?? title) : nil,
            overview: overview ?? "",
            releaseDate: type == .movie ? releaseDate : nil,
            firstAirDate: type == .tv ? firstAirDate : nil,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            voteCount: voteCount,
            genreIds: genreIds
        )
    }
}

private enum NFTitleCodingKeys: String, CodingKey {
    case id
    case mediaType = "media_type"
    case title
    case name
    case overview
    case releaseDate = "release_date"
    case firstAirDate = "first_air_date"
    case posterPath = "poster_path"
    case backdropPath = "backdrop_path"
    case voteAverage = "vote_average"
    case voteCount = "vote_count"
    case genreIds = "genre_ids"
    case knownFor = "known_for"
}

/// A title a person is known for (inside a multi-search "person" result).
struct NFKnownForTitle: Decodable, NFTitleFields {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genreIds: [Int]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NFTitleCodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        mediaType = try? container.decodeIfPresent(String.self, forKey: .mediaType)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        overview = try? container.decodeIfPresent(String.self, forKey: .overview)
        releaseDate = try? container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try? container.decodeIfPresent(String.self, forKey: .firstAirDate)
        posterPath = try? container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try? container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try? container.decodeIfPresent(Double.self, forKey: .voteAverage)
        voteCount = try? container.decodeIfPresent(Int.self, forKey: .voteCount)
        genreIds = try? container.decodeIfPresent([Int].self, forKey: .genreIds)
    }
}

/// Any TMDB list result (movie, series, trending, recommendation, person).
struct NFRawTitle: Decodable, NFTitleFields {
    let id: Int
    let mediaType: String?
    let title: String?
    let name: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let genreIds: [Int]?
    let knownFor: [NFLossy<NFKnownForTitle>]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: NFTitleCodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        mediaType = try? container.decodeIfPresent(String.self, forKey: .mediaType)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        name = try? container.decodeIfPresent(String.self, forKey: .name)
        overview = try? container.decodeIfPresent(String.self, forKey: .overview)
        releaseDate = try? container.decodeIfPresent(String.self, forKey: .releaseDate)
        firstAirDate = try? container.decodeIfPresent(String.self, forKey: .firstAirDate)
        posterPath = try? container.decodeIfPresent(String.self, forKey: .posterPath)
        backdropPath = try? container.decodeIfPresent(String.self, forKey: .backdropPath)
        voteAverage = try? container.decodeIfPresent(Double.self, forKey: .voteAverage)
        voteCount = try? container.decodeIfPresent(Int.self, forKey: .voteCount)
        genreIds = try? container.decodeIfPresent([Int].self, forKey: .genreIds)
        knownFor = try? container.decodeIfPresent([NFLossy<NFKnownForTitle>].self, forKey: .knownFor)
    }
}

struct NFImageFile: Decodable {
    let filePath: String
    let language: String?
    let voteAverage: Double?
    let aspectRatio: Double?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case language = "iso_639_1"
        case voteAverage = "vote_average"
        case aspectRatio = "aspect_ratio"
    }

    var isRaster: Bool {
        !filePath.lowercased().hasSuffix(".svg")
    }
}

struct NFImagesPayload: Decodable {
    let logos: [NFLossy<NFImageFile>]?
    let posters: [NFLossy<NFImageFile>]?
    let backdrops: [NFLossy<NFImageFile>]?
}

struct NFCastPayload: Decodable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?

    enum CodingKeys: String, CodingKey {
        case id, name, character
        case profilePath = "profile_path"
    }
}

struct NFCrewPayload: Decodable {
    let id: Int
    let name: String
    let job: String?
}

struct NFCreditsPayload: Decodable {
    let cast: [NFLossy<NFCastPayload>]?
    let crew: [NFLossy<NFCrewPayload>]?
}

struct NFVideoPayload: Decodable, Hashable, Identifiable {
    let id: String
    let key: String
    let name: String
    let site: String
    let type: String
    let official: Bool?
    let language: String?

    enum CodingKeys: String, CodingKey {
        case id, key, name, site, type, official
        case language = "iso_639_1"
    }

    var isYouTube: Bool {
        site.caseInsensitiveCompare("YouTube") == .orderedSame
    }

    var watchURL: URL? {
        guard isYouTube else { return nil }
        return URL(string: "https://m.youtube.com/watch?v=\(key)")
    }

    var thumbnailURL: URL? {
        guard isYouTube else { return nil }
        return URL(string: "https://img.youtube.com/vi/\(key)/hqdefault.jpg")
    }
}

struct NFVideosPayload: Decodable {
    let results: [NFLossy<NFVideoPayload>]?
}

struct NFSeasonSummary: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let seasonNumber: Int
    let episodeCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case seasonNumber = "season_number"
        case episodeCount = "episode_count"
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return seasonNumber == 0 ? "Specials" : "Season \(seasonNumber)"
    }
}

struct NFListPayload: Decodable {
    let results: [NFLossy<NFRawTitle>]?
}

struct NFReleaseDatesPayload: Decodable {
    struct Country: Decodable {
        struct Entry: Decodable {
            let certification: String?
        }

        let country: String
        let releaseDates: [NFLossy<Entry>]?

        enum CodingKeys: String, CodingKey {
            case country = "iso_3166_1"
            case releaseDates = "release_dates"
        }
    }

    let results: [NFLossy<Country>]?
}

struct NFContentRatingsPayload: Decodable {
    struct Rating: Decodable {
        let country: String
        let rating: String?

        enum CodingKeys: String, CodingKey {
            case country = "iso_3166_1"
            case rating
        }
    }

    let results: [NFLossy<Rating>]?
}

struct NFNamedPayload: Decodable, Hashable {
    let id: Int
    let name: String
}

/// Everything the title page shows, from one request (`append_to_response`).
struct NFTitlePayload: Decodable {
    let id: Int
    let title: String?
    let name: String?
    let tagline: String?
    let overview: String?
    let releaseDate: String?
    let firstAirDate: String?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let numberOfSeasons: Int?
    let status: String?
    let genres: [NFLossy<NFNamedPayload>]?
    let voteAverage: Double?
    let voteCount: Int?
    let posterPath: String?
    let backdropPath: String?
    let createdBy: [NFLossy<NFNamedPayload>]?
    let seasons: [NFLossy<NFSeasonSummary>]?
    let credits: NFCreditsPayload?
    let videos: NFVideosPayload?
    let images: NFImagesPayload?
    let recommendations: NFListPayload?
    let similar: NFListPayload?
    let releaseDates: NFReleaseDatesPayload?
    let contentRatings: NFContentRatingsPayload?

    enum CodingKeys: String, CodingKey {
        case id, title, name, tagline, overview, runtime, status, genres, seasons
        case credits, videos, images, recommendations, similar
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case episodeRunTime = "episode_run_time"
        case numberOfSeasons = "number_of_seasons"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case createdBy = "created_by"
        case releaseDates = "release_dates"
        case contentRatings = "content_ratings"
    }
}

struct NFEpisodePayload: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let overview: String?
    let episodeNumber: Int
    let seasonNumber: Int
    let stillPath: String?
    let runtime: Int?
    let airDate: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview, runtime
        case episodeNumber = "episode_number"
        case seasonNumber = "season_number"
        case stillPath = "still_path"
        case airDate = "air_date"
    }

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return "Episode \(episodeNumber)"
    }

    /// Whether the episode has aired (unaired episodes can't be streamed yet).
    var hasAired: Bool {
        guard let date = NF.date(fromTMDB: airDate) else { return true }
        return date <= Date()
    }
}

struct NFSeasonPayload: Decodable {
    let id: Int?
    let seasonNumber: Int?
    let episodes: [NFLossy<NFEpisodePayload>]?

    enum CodingKeys: String, CodingKey {
        case id, episodes
        case seasonNumber = "season_number"
    }
}

// MARK: - Service

/// Typed TMDB calls for the interface, on top of `TMDBService`'s cache.
enum NFCatalogService {
    private static let service = TMDBService()

    static func list(
        path: String,
        query: [String: String] = [:],
        fallbackType: WatchType?
    ) async throws -> [MediaItem] {
        let raw = try await service.fetchResults(
            NFLossy<NFRawTitle>.self,
            path: path,
            queryItems: queryItems(query)
        )

        return raw.compactMap { $0.value?.mediaItem(fallback: fallbackType) }
    }

    /// Multi-search, expanding matching people into the titles they're known for.
    static func search(_ query: String) async throws -> [MediaItem] {
        let raw = try await service.fetchResults(
            NFLossy<NFRawTitle>.self,
            path: "/3/search/multi",
            queryItems: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "include_adult", value: "false")
            ]
        )

        var direct: [MediaItem] = []
        var viaPeople: [MediaItem] = []

        for entry in raw.compactMap(\.value) {
            if entry.mediaType == "person" {
                viaPeople += (entry.knownFor ?? []).compactMap { $0.value?.mediaItem(fallback: nil) }
            } else if let item = entry.mediaItem(fallback: nil) {
                direct.append(item)
            }
        }

        var seen = Set<String>()
        return (direct + viaPeople).filter { $0.posterPath != nil && seen.insert($0.nfKey).inserted }
    }

    static func images(type: WatchType, id: Int) async throws -> NFImagesPayload {
        try await service.fetchObject(
            NFImagesPayload.self,
            path: "/3/\(type.tmdbPath)/\(id)/images",
            queryItems: [URLQueryItem(name: "include_image_language", value: "en,null")]
        )
    }

    static func title(type: WatchType, id: Int) async throws -> NFTitlePayload {
        let appended = type == .movie
            ? "credits,videos,images,release_dates,recommendations,similar"
            : "credits,videos,images,content_ratings,recommendations,similar"

        return try await service.fetchObject(
            NFTitlePayload.self,
            path: "/3/\(type.tmdbPath)/\(id)",
            queryItems: [
                URLQueryItem(name: "append_to_response", value: appended),
                URLQueryItem(name: "include_image_language", value: "en,null"),
                URLQueryItem(name: "include_video_language", value: "en,null")
            ]
        )
    }

    static func season(seriesId: Int, number: Int) async throws -> [NFEpisodePayload] {
        let payload = try await service.fetchObject(
            NFSeasonPayload.self,
            path: "/3/tv/\(seriesId)/season/\(number)"
        )
        return (payload.episodes ?? []).compactMap(\.value)
    }

    private static func queryItems(_ query: [String: String]) -> [URLQueryItem] {
        query
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}

// MARK: - Artwork (title logos, textless key art)

struct NFArtwork: Equatable {
    var logoPath: String?
    var logoAspectRatio: Double?
    /// Poster without the title baked in — lets a logo sit on top of it.
    var textlessPosterPath: String?
    var textlessBackdropPath: String?

    static let empty = NFArtwork()

    init(
        logoPath: String? = nil,
        logoAspectRatio: Double? = nil,
        textlessPosterPath: String? = nil,
        textlessBackdropPath: String? = nil
    ) {
        self.logoPath = logoPath
        self.logoAspectRatio = logoAspectRatio
        self.textlessPosterPath = textlessPosterPath
        self.textlessBackdropPath = textlessBackdropPath
    }

    init(images: NFImagesPayload) {
        func best(_ files: [NFLossy<NFImageFile>]?, language: (String?) -> Bool) -> NFImageFile? {
            (files ?? [])
                .compactMap(\.value)
                .filter { $0.isRaster && language($0.language) }
                .max { ($0.voteAverage ?? 0) < ($1.voteAverage ?? 0) }
        }

        let logo = best(images.logos) { $0 == "en" } ?? best(images.logos) { $0 == nil }
        self.init(
            logoPath: logo?.filePath,
            logoAspectRatio: logo?.aspectRatio,
            textlessPosterPath: best(images.posters) { $0 == nil }?.filePath,
            textlessBackdropPath: best(images.backdrops) { $0 == nil }?.filePath
        )
    }
}

/// Caches per-title artwork lookups and shares in-flight requests.
@Observable
final class NFArtworkStore {
    private(set) var entries: [String: NFArtwork] = [:]
    @ObservationIgnored private var inFlight: [String: Task<NFArtwork, Never>] = [:]

    func artwork(for item: MediaItem) -> NFArtwork? {
        entries[item.nfKey]
    }

    @discardableResult
    func load(_ item: MediaItem) async -> NFArtwork {
        let key = item.nfKey
        if let cached = entries[key] {
            return cached
        }

        if let existing = inFlight[key] {
            return await existing.value
        }

        let type = item.nfType
        let id = item.id
        let task = Task<NFArtwork, Never> {
            guard let images = try? await NFCatalogService.images(type: type, id: id) else {
                return .empty
            }
            return NFArtwork(images: images)
        }

        inFlight[key] = task
        let artwork = await task.value
        inFlight[key] = nil
        entries[key] = artwork
        return artwork
    }

    /// Seeds the cache from a title payload that already includes images.
    func store(_ artwork: NFArtwork, for item: MediaItem) {
        entries[item.nfKey] = artwork
    }
}

// MARK: - Saved titles (likes, reminders)

/// A compact, codable snapshot of a title for local lists.
struct NFSavedTitle: Codable, Hashable, Identifiable {
    let id: Int
    let mediaType: String
    let title: String
    let posterPath: String?
    let backdropPath: String?
    let overview: String
    let date: String?
    let genreIds: [Int]?
    let voteAverage: Double?

    init(_ item: MediaItem) {
        id = item.id
        mediaType = item.mediaType
        title = item.displayTitle
        posterPath = item.posterPath
        backdropPath = item.backdropPath
        overview = item.overview
        date = item.isMovie ? item.releaseDate : item.firstAirDate
        genreIds = item.genreIds
        voteAverage = item.voteAverage
    }

    var key: String { "\(mediaType)-\(id)" }

    var mediaItem: MediaItem {
        let isMovie = mediaType == "movie"
        return MediaItem(
            id: id,
            mediaType: mediaType,
            title: isMovie ? title : nil,
            name: isMovie ? nil : title,
            overview: overview,
            releaseDate: isMovie ? date : nil,
            firstAirDate: isMovie ? nil : date,
            posterPath: posterPath,
            backdropPath: backdropPath,
            voteAverage: voteAverage,
            genreIds: genreIds
        )
    }
}

struct NFReminder: Codable, Hashable, Identifiable {
    let title: NFSavedTitle
    let releaseDate: Date

    var id: String { title.key }
}

struct NFRank: Equatable {
    let rank: Int
    let listName: String
}

/// Local, per-device state the interface adds on top of the existing managers:
/// thumbs-up ratings, release reminders, today's Top 10 ranks and artwork.
@Observable
final class NFLibrary {
    let artwork = NFArtworkStore()

    private(set) var liked: [NFSavedTitle] = []
    private(set) var reminders: [NFReminder] = []
    private(set) var ranks: [String: NFRank] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    private static let likedKey = "nf.likedTitles"
    private static let remindersKey = "nf.reminders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        liked = Self.decode([NFSavedTitle].self, from: defaults.data(forKey: Self.likedKey)) ?? []
        reminders = (Self.decode([NFReminder].self, from: defaults.data(forKey: Self.remindersKey)) ?? [])
            .filter { $0.releaseDate >= Calendar.current.startOfDay(for: Date()) }
    }

    // MARK: Likes

    func isLiked(_ item: MediaItem) -> Bool {
        liked.contains { $0.key == item.nfKey }
    }

    func toggleLike(_ item: MediaItem) {
        if isLiked(item) {
            liked.removeAll { $0.key == item.nfKey }
        } else {
            liked.insert(NFSavedTitle(item), at: 0)
        }
        save(liked, key: Self.likedKey)
    }

    // MARK: Top 10

    func rank(for item: MediaItem) -> NFRank? {
        ranks[item.nfKey]
    }

    func recordRanks(_ items: [MediaItem], listName: String) {
        for (index, item) in items.prefix(10).enumerated() {
            ranks[item.nfKey] = NFRank(rank: index + 1, listName: listName)
        }
    }

    // MARK: Reminders

    enum ReminderResult {
        case added
        case removed
        case notificationsDenied
    }

    func hasReminder(_ item: MediaItem) -> Bool {
        reminders.contains { $0.id == item.nfKey }
    }

    func toggleReminder(_ item: MediaItem, releaseDate: Date) async -> ReminderResult {
        let center = UNUserNotificationCenter.current()
        let identifier = "nightflix.reminder.\(item.nfKey)"

        if hasReminder(item) {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            reminders.removeAll { $0.id == item.nfKey }
            save(reminders, key: Self.remindersKey)
            return .removed
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return .notificationsDenied }

        let content = UNMutableNotificationContent()
        content.title = "\(item.displayTitle) is out today"
        content.body = item.isMovie
            ? "The film you asked to be reminded about has been released."
            : "The series you asked to be reminded about has premiered."
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: releaseDate)
        components.hour = 10
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))

        reminders.append(NFReminder(title: NFSavedTitle(item), releaseDate: releaseDate))
        reminders.sort { $0.releaseDate < $1.releaseDate }
        save(reminders, key: Self.remindersKey)
        return .added
    }

    // MARK: Persistence

    private func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
