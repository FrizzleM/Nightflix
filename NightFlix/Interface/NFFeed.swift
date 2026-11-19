import Foundation
import Observation

// MARK: - Browse scope & categories

enum NFBrowseScope: String, Hashable, CaseIterable {
    case all
    case series
    case films

    var label: String {
        switch self {
        case .all: return "All"
        case .series: return "Series"
        case .films: return "Films"
        }
    }
}

/// A browsable genre. Movie and TV genre ids differ on TMDB, so each category maps to
/// one or both (`with_genres` values; `|` means "any of").
struct NFCategory: Identifiable, Hashable {
    let id: String
    let name: String
    let movieGenres: String?
    let tvGenres: String?

    func supports(_ scope: NFBrowseScope) -> Bool {
        switch scope {
        case .all: return movieGenres != nil || tvGenres != nil
        case .series: return tvGenres != nil
        case .films: return movieGenres != nil
        }
    }

    static let catalog: [NFCategory] = [
        NFCategory(id: "action", name: "Action", movieGenres: "28", tvGenres: "10759"),
        NFCategory(id: "adventure", name: "Adventure", movieGenres: "12", tvGenres: "10759"),
        NFCategory(id: "animation", name: "Animation", movieGenres: "16", tvGenres: "16"),
        NFCategory(id: "comedy", name: "Comedy", movieGenres: "35", tvGenres: "35"),
        NFCategory(id: "crime", name: "Crime", movieGenres: "80", tvGenres: "80"),
        NFCategory(id: "documentary", name: "Documentaries", movieGenres: "99", tvGenres: "99"),
        NFCategory(id: "drama", name: "Drama", movieGenres: "18", tvGenres: "18"),
        NFCategory(id: "family", name: "Family", movieGenres: "10751", tvGenres: "10751"),
        NFCategory(id: "fantasy", name: "Fantasy", movieGenres: "14", tvGenres: "10765"),
        NFCategory(id: "history", name: "History", movieGenres: "36", tvGenres: nil),
        NFCategory(id: "horror", name: "Horror", movieGenres: "27", tvGenres: nil),
        NFCategory(id: "kids", name: "Kids", movieGenres: "10751|16", tvGenres: "10762"),
        NFCategory(id: "music", name: "Music", movieGenres: "10402", tvGenres: nil),
        NFCategory(id: "mystery", name: "Mystery", movieGenres: "9648", tvGenres: "9648"),
        NFCategory(id: "reality", name: "Reality", movieGenres: nil, tvGenres: "10764"),
        NFCategory(id: "romance", name: "Romance", movieGenres: "10749", tvGenres: nil),
        NFCategory(id: "scifi", name: "Sci-Fi", movieGenres: "878", tvGenres: "10765"),
        NFCategory(id: "thriller", name: "Thrillers", movieGenres: "53", tvGenres: "80|9648"),
        NFCategory(id: "war", name: "War", movieGenres: "10752", tvGenres: "10768"),
        NFCategory(id: "western", name: "Westerns", movieGenres: "37", tvGenres: "37")
    ]
}

// MARK: - Rows

struct NFSource: Hashable {
    let path: String
    var query: [String: String] = [:]
    /// Used when the endpoint's results don't carry `media_type`.
    var type: WatchType?

    static func discover(
        _ type: WatchType,
        genres: String?,
        sort: String = "popularity.desc",
        extra: [String: String] = [:]
    ) -> NFSource {
        var query = ["sort_by": sort, "include_adult": "false"]
        if let genres { query["with_genres"] = genres }
        if type == .tv { query["without_genres"] = "10763,10767,10766" }
        query.merge(extra) { _, new in new }
        return NFSource(path: "/3/discover/\(type.tmdbPath)", query: query, type: type)
    }
}

struct NFRow: Identifiable, Hashable {
    enum Style: Hashable {
        case posters
        case top10
        case continueWatching
        case myList
    }

    let id: String
    let title: String
    var style: Style = .posters
    var sources: [NFSource] = []
    /// For Top 10 rows: how the rank reads on a title page ("Series Today").
    var rankListName: String?
    /// Titles to keep out of the row (e.g. already watched, for recommendations).
    var excludedKeys: Set<String> = []
}

/// The rails for each browse scope, in display order.
enum NFRowCatalog {
    static func rows(scope: NFBrowseScope, category: NFCategory?) -> [NFRow] {
        if let category {
            return categoryRows(category, scope: scope)
        }

        switch scope {
        case .all: return allRows
        case .series: return seriesRows
        case .films: return filmRows
        }
    }

    static func heroSource(scope: NFBrowseScope, category: NFCategory?) -> NFSource {
        if let category {
            if scope != .series, let genres = category.movieGenres {
                return .discover(.movie, genres: genres, extra: ["vote_count.gte": "300"])
            }
            return .discover(.tv, genres: category.tvGenres, extra: ["vote_count.gte": "150"])
        }

        switch scope {
        case .all: return NFSource(path: "/3/trending/all/day")
        case .series: return NFSource(path: "/3/trending/tv/day", type: .tv)
        case .films: return NFSource(path: "/3/trending/movie/day", type: .movie)
        }
    }

    private static let today = NF.tmdbDay(offsetDays: 0)

    private static var allRows: [NFRow] {
        [
            NFRow(id: "continue", title: "Continue Watching", style: .continueWatching),
            NFRow(id: "trending-all", title: "Trending Now", sources: [NFSource(path: "/3/trending/all/week")]),
            NFRow(id: "top10-tv", title: "Top 10 Series Today", style: .top10,
                  sources: [NFSource(path: "/3/trending/tv/day", type: .tv)], rankListName: "Series Today"),
            NFRow(id: "now-playing", title: "New Releases",
                  sources: [NFSource(path: "/3/movie/now_playing", type: .movie)]),
            NFRow(id: "my-list", title: "My List", style: .myList),
            NFRow(id: "popular-mixed", title: "Popular on Nightflix", sources: [
                NFSource(path: "/3/movie/popular", type: .movie),
                .discover(.tv, genres: nil, extra: ["vote_count.gte": "200"])
            ]),
            NFRow(id: "top10-movie", title: "Top 10 Films Today", style: .top10,
                  sources: [NFSource(path: "/3/trending/movie/day", type: .movie)], rankListName: "Films Today"),
            NFRow(id: "on-the-air", title: "New Episodes",
                  sources: [NFSource(path: "/3/tv/on_the_air", type: .tv)]),
            NFRow(id: "mix-action", title: "Action & Adventure", sources: [
                .discover(.movie, genres: "28|12", extra: ["vote_count.gte": "400"]),
                .discover(.tv, genres: "10759", extra: ["vote_count.gte": "150"])
            ]),
            NFRow(id: "mix-comedy", title: "Comedies", sources: [
                .discover(.movie, genres: "35", extra: ["vote_count.gte": "400"]),
                .discover(.tv, genres: "35", extra: ["vote_count.gte": "150"])
            ]),
            NFRow(id: "mix-scifi", title: "Sci-Fi & Fantasy", sources: [
                .discover(.movie, genres: "878|14", extra: ["vote_count.gte": "400"]),
                .discover(.tv, genres: "10765", extra: ["vote_count.gte": "150"])
            ]),
            NFRow(id: "mix-crime", title: "Crime & Thrillers", sources: [
                .discover(.movie, genres: "80|53", extra: ["vote_count.gte": "400"]),
                .discover(.tv, genres: "80", extra: ["vote_count.gte": "150"])
            ]),
            NFRow(id: "mix-animation", title: "Animation", sources: [
                .discover(.movie, genres: "16", extra: ["vote_count.gte": "300"]),
                .discover(.tv, genres: "16", extra: ["vote_count.gte": "150"])
            ]),
            NFRow(id: "movie-horror", title: "Horror Films", sources: [
                .discover(.movie, genres: "27", extra: ["vote_count.gte": "300"])
            ]),
            NFRow(id: "mix-docs", title: "Documentaries", sources: [
                .discover(.movie, genres: "99", extra: ["vote_count.gte": "100"]),
                .discover(.tv, genres: "99", extra: ["vote_count.gte": "40"])
            ]),
            NFRow(id: "movie-romance", title: "Romantic Films", sources: [
                .discover(.movie, genres: "10749", extra: ["vote_count.gte": "300"])
            ]),
            NFRow(id: "mix-family", title: "Family Night", sources: [
                .discover(.movie, genres: "10751", extra: ["vote_count.gte": "300"]),
                .discover(.tv, genres: "10751", extra: ["vote_count.gte": "80"])
            ]),
            NFRow(id: "acclaimed-mixed", title: "Critically Acclaimed", sources: [
                NFSource(path: "/3/movie/top_rated", type: .movie),
                NFSource(path: "/3/tv/top_rated", type: .tv)
            ])
        ]
    }

    private static var seriesRows: [NFRow] {
        var rows = [
            NFRow(id: "continue", title: "Continue Watching", style: .continueWatching),
            NFRow(id: "trending-tv", title: "Trending Series",
                  sources: [NFSource(path: "/3/trending/tv/week", type: .tv)]),
            NFRow(id: "top10-tv", title: "Top 10 Series Today", style: .top10,
                  sources: [NFSource(path: "/3/trending/tv/day", type: .tv)], rankListName: "Series Today"),
            NFRow(id: "on-the-air", title: "New Episodes",
                  sources: [NFSource(path: "/3/tv/on_the_air", type: .tv)]),
            NFRow(id: "popular-tv", title: "Popular Series",
                  sources: [.discover(.tv, genres: nil, extra: ["vote_count.gte": "200"])])
        ]

        let genres: [(String, String, String)] = [
            ("tv-drama", "Drama Series", "18"),
            ("tv-crime", "Crime Series", "80"),
            ("tv-comedy", "Comedy Series", "35"),
            ("tv-scifi", "Sci-Fi & Fantasy Series", "10765"),
            ("tv-action", "Action & Adventure Series", "10759"),
            ("tv-mystery", "Mysteries", "9648"),
            ("tv-animation", "Animated Series", "16"),
            ("tv-reality", "Reality TV", "10764"),
            ("tv-docs", "Docuseries", "99"),
            ("tv-kids", "Kids' TV", "10762")
        ]

        rows += genres.map { id, title, genre in
            NFRow(id: id, title: title, sources: [.discover(.tv, genres: genre, extra: ["vote_count.gte": "60"])])
        }

        rows.append(NFRow(id: "acclaimed-tv", title: "Binge-Worthy Series",
                          sources: [NFSource(path: "/3/tv/top_rated", type: .tv)]))
        rows.insert(NFRow(id: "my-list", title: "My List", style: .myList), at: 4)
        return rows
    }

    private static var filmRows: [NFRow] {
        var rows = [
            NFRow(id: "continue", title: "Continue Watching", style: .continueWatching),
            NFRow(id: "trending-movie", title: "Trending Films",
                  sources: [NFSource(path: "/3/trending/movie/week", type: .movie)]),
            NFRow(id: "top10-movie", title: "Top 10 Films Today", style: .top10,
                  sources: [NFSource(path: "/3/trending/movie/day", type: .movie)], rankListName: "Films Today"),
            NFRow(id: "now-playing", title: "New Releases",
                  sources: [NFSource(path: "/3/movie/now_playing", type: .movie)]),
            NFRow(id: "popular-movie", title: "Popular Films",
                  sources: [NFSource(path: "/3/movie/popular", type: .movie)])
        ]

        let genres: [(String, String, String)] = [
            ("movie-action", "Action Films", "28"),
            ("movie-comedy", "Comedies", "35"),
            ("movie-thriller", "Thrillers", "53"),
            ("movie-scifi", "Sci-Fi Films", "878"),
            ("movie-horror", "Horror Films", "27"),
            ("movie-drama", "Dramas", "18"),
            ("movie-romance", "Romantic Films", "10749"),
            ("movie-animation", "Animated Films", "16"),
            ("movie-crime", "Crime Films", "80"),
            ("movie-adventure", "Adventures", "12"),
            ("movie-family", "Family Films", "10751"),
            ("movie-docs", "Documentaries", "99")
        ]

        rows += genres.map { id, title, genre in
            NFRow(id: id, title: title, sources: [.discover(.movie, genres: genre, extra: ["vote_count.gte": "300"])])
        }

        rows.append(NFRow(id: "acclaimed-movie", title: "Critically Acclaimed Films",
                          sources: [NFSource(path: "/3/movie/top_rated", type: .movie)]))
        rows.insert(NFRow(id: "my-list", title: "My List", style: .myList), at: 4)
        return rows
    }

    private static func categoryRows(_ category: NFCategory, scope: NFBrowseScope) -> [NFRow] {
        let movieGenres = scope == .series ? nil : category.movieGenres
        let tvGenres = scope == .films ? nil : category.tvGenres
        let prefix = "cat-\(category.id)-\(scope.rawValue)"

        func sources(
            movieSort: String,
            tvSort: String,
            movieExtra: [String: String],
            tvExtra: [String: String]
        ) -> [NFSource] {
            var result: [NFSource] = []
            if let movieGenres {
                result.append(.discover(.movie, genres: movieGenres, sort: movieSort, extra: movieExtra))
            }
            if let tvGenres {
                result.append(.discover(.tv, genres: tvGenres, sort: tvSort, extra: tvExtra))
            }
            return result
        }

        var rows: [NFRow] = [
            NFRow(id: "\(prefix)-popular", title: "Popular \(category.name)", sources: sources(
                movieSort: "popularity.desc", tvSort: "popularity.desc",
                movieExtra: ["vote_count.gte": "150"], tvExtra: ["vote_count.gte": "60"]
            )),
            NFRow(id: "\(prefix)-new", title: "New \(category.name)", sources: sources(
                movieSort: "primary_release_date.desc", tvSort: "first_air_date.desc",
                movieExtra: ["vote_count.gte": "40", "primary_release_date.lte": today],
                tvExtra: ["vote_count.gte": "15", "first_air_date.lte": today]
            )),
            NFRow(id: "\(prefix)-acclaimed", title: "Critically Acclaimed \(category.name)", sources: sources(
                movieSort: "vote_average.desc", tvSort: "vote_average.desc",
                movieExtra: ["vote_count.gte": "1500"], tvExtra: ["vote_count.gte": "400"]
            )),
            NFRow(id: "\(prefix)-gems", title: "Hidden Gems", sources: sources(
                movieSort: "vote_average.desc", tvSort: "vote_average.desc",
                movieExtra: ["vote_count.gte": "150", "vote_count.lte": "1200"],
                tvExtra: ["vote_count.gte": "60", "vote_count.lte": "400"]
            )),
            NFRow(id: "\(prefix)-classic", title: "Classic \(category.name)", sources: sources(
                movieSort: "vote_count.desc", tvSort: "vote_count.desc",
                movieExtra: ["primary_release_date.lte": "2004-12-31"],
                tvExtra: ["first_air_date.lte": "2008-12-31"]
            ))
        ]

        if movieGenres != nil && tvGenres != nil {
            rows.insert(NFRow(id: "\(prefix)-series", title: "\(category.name) Series", sources: [
                .discover(.tv, genres: tvGenres, extra: ["vote_count.gte": "100"])
            ]), at: 2)
            rows.insert(NFRow(id: "\(prefix)-films", title: "\(category.name) Films", sources: [
                .discover(.movie, genres: movieGenres, extra: ["vote_count.gte": "500"])
            ]), at: 3)
        }

        return rows
    }

    static func recommendationsRow(for seed: NFPersonalSeed, excluding watched: Set<String>) -> NFRow {
        NFRow(
            id: "because-\(seed.key)",
            title: "Because You Watched \(seed.title)",
            sources: [NFSource(path: "/3/\(seed.type.tmdbPath)/\(seed.id)/recommendations", type: seed.type)],
            excludedKeys: watched.union([seed.key])
        )
    }
}

struct NFPersonalSeed: Hashable {
    let id: Int
    let type: WatchType
    let title: String

    var key: String { "\(type.tmdbPath)-\(id)" }
}

// MARK: - Feed model

/// Home feed state: the rails for the current scope (loaded lazily as they scroll into
/// view), the hero title with its artwork, and personalised "Because You Watched" rails.
@Observable
final class NFFeedModel {
    private(set) var scope: NFBrowseScope = .all
    private(set) var category: NFCategory?
    private(set) var rows: [NFRow] = []
    private(set) var rowItems: [String: [MediaItem]] = [:]
    private(set) var failedRows: Set<String> = []
    /// Series currently airing new episodes (from the "New Episodes" rail), for badges.
    private(set) var onAirKeys: Set<String> = []

    private(set) var hero: MediaItem?
    private(set) var heroArtwork: NFArtwork?
    private(set) var isLoadingHero = false
    private(set) var heroFailed = false

    @ObservationIgnored private var loadingRows: Set<String> = []
    @ObservationIgnored private var heroCache: [String: (item: MediaItem, artwork: NFArtwork)] = [:]
    @ObservationIgnored private var personalRows: [NFRow] = []
    @ObservationIgnored private var personalSignature = ""

    private let library: NFLibrary

    init(library: NFLibrary) {
        self.library = library
        rebuildRows()
    }

    var scopeKey: String {
        "\(scope.rawValue)|\(category?.id ?? "-")"
    }

    func setScope(_ scope: NFBrowseScope, category: NFCategory?) {
        guard scope != self.scope || category != self.category else { return }

        self.scope = scope
        self.category = category

        if let cached = heroCache[scopeKey] {
            hero = cached.item
            heroArtwork = cached.artwork
        } else {
            hero = nil
            heroArtwork = nil
        }

        rebuildRows()
    }

    /// Rebuilds the "Because You Watched" rails from the most recent distinct titles.
    func updatePersonalization(history: [WatchItem]) {
        var seeds: [NFPersonalSeed] = []
        var seen = Set<String>()

        for item in history {
            guard let id = Int(item.tmdbId) else { continue }
            let seed = NFPersonalSeed(id: id, type: item.type, title: item.title)
            guard seen.insert(seed.key).inserted else { continue }
            seeds.append(seed)
            if seeds.count == 3 { break }
        }

        let signature = seeds.map(\.key).joined(separator: ",")
        guard signature != personalSignature else { return }
        personalSignature = signature

        let watched = Set(history.compactMap { item -> String? in
            guard let id = Int(item.tmdbId) else { return nil }
            return "\(item.type.tmdbPath)-\(id)"
        })

        personalRows = seeds.map { NFRowCatalog.recommendationsRow(for: $0, excluding: watched) }
        for row in personalRows {
            rowItems[row.id] = nil
        }
        rebuildRows()
    }

    private func rebuildRows() {
        var result = NFRowCatalog.rows(scope: scope, category: category)

        let relevantPersonal = personalRows.filter { row in
            switch scope {
            case .all: return true
            case .series: return row.id.contains("because-tv-")
            case .films: return row.id.contains("because-movie-")
            }
        }

        if category == nil, !relevantPersonal.isEmpty {
            // Interleave personal rails among the catalogue rails.
            let slots = [4, 8, 11]
            for (index, row) in relevantPersonal.enumerated() {
                let position = min(slots[min(index, slots.count - 1)] + index, result.count)
                result.insert(row, at: position)
            }
        }

        rows = result
    }

    // MARK: Rows

    func items(for row: NFRow) -> [MediaItem]? {
        rowItems[row.id]
    }

    func isLoading(_ row: NFRow) -> Bool {
        rowItems[row.id] == nil && !failedRows.contains(row.id)
    }

    func load(_ row: NFRow) async {
        guard !row.sources.isEmpty,
              rowItems[row.id] == nil,
              !loadingRows.contains(row.id) else {
            return
        }

        loadingRows.insert(row.id)
        failedRows.remove(row.id)

        let tasks = row.sources.map { source in
            Task { () -> [MediaItem]? in
                try? await NFCatalogService.list(path: source.path, query: source.query, fallbackType: source.type)
            }
        }

        var lists: [[MediaItem]] = []
        var anySucceeded = false
        for task in tasks {
            if let items = await task.value {
                anySucceeded = true
                lists.append(items)
            }
        }

        loadingRows.remove(row.id)

        guard anySucceeded else {
            failedRows.insert(row.id)
            return
        }

        var seen = row.excludedKeys
        let limit = row.style == .top10 ? 10 : 24
        let merged = Self.interleave(lists)
            .filter { $0.isBrowsable && seen.insert($0.nfKey).inserted }
            .prefix(limit)

        let items = Array(merged)
        rowItems[row.id] = items

        if row.style == .top10, let listName = row.rankListName {
            library.recordRanks(items, listName: listName)
        }

        if row.id == "on-the-air" {
            onAirKeys.formUnion(items.map(\.nfKey))
        }

        NFImagePipeline.shared.prefetch(items.prefix(6).compactMap { NF.imageURL($0.posterPath, .poster) })
    }

    func retry(_ row: NFRow) async {
        failedRows.remove(row.id)
        rowItems[row.id] = nil
        await load(row)
    }

    private static func interleave(_ lists: [[MediaItem]]) -> [MediaItem] {
        guard lists.count > 1 else { return lists.first ?? [] }

        var result: [MediaItem] = []
        let longest = lists.map(\.count).max() ?? 0
        for index in 0..<longest {
            for list in lists where index < list.count {
                result.append(list[index])
            }
        }
        return result
    }

    // MARK: Hero

    func loadHero() async {
        let key = scopeKey

        if let cached = heroCache[key] {
            hero = cached.item
            heroArtwork = cached.artwork
            return
        }

        isLoadingHero = true
        heroFailed = false

        let source = NFRowCatalog.heroSource(scope: scope, category: category)
        let items = try? await NFCatalogService.list(path: source.path, query: source.query, fallbackType: source.type)

        guard key == scopeKey else { return }

        guard let items, !items.isEmpty else {
            isLoadingHero = false
            heroFailed = true
            return
        }

        let candidates = Array(items.filter { $0.isBrowsable && $0.backdropPath != nil }.prefix(6))
        let pool = candidates.isEmpty ? Array(items.prefix(1)) : candidates

        let lookups = pool.map { item in
            Task { (item, await library.artwork.load(item)) }
        }

        var resolved: [(item: MediaItem, artwork: NFArtwork)] = []
        for lookup in lookups {
            let (item, artwork) = await lookup.value
            resolved.append((item, artwork))
        }

        guard key == scopeKey else { return }

        // Prefer textless key art with a title logo on top — it reads like a real
        // marquee. Fall back to anything with a logo, then to the first title.
        let ideal = resolved.filter { $0.artwork.logoPath != nil && $0.artwork.textlessPosterPath != nil }
        let chosen = ideal.prefix(3).randomElement()
            ?? resolved.first { $0.artwork.logoPath != nil }
            ?? resolved.first

        guard let chosen else {
            isLoadingHero = false
            heroFailed = true
            return
        }

        heroCache[key] = chosen
        hero = chosen.item
        heroArtwork = chosen.artwork
        isLoadingHero = false
    }
}

// MARK: - New & Hot

@Observable
final class NFNewHotModel {
    struct Upcoming: Identifiable, Hashable {
        let item: MediaItem
        let date: Date

        var id: String { item.nfKey }
    }

    private(set) var comingSoon: [Upcoming] = []
    private(set) var everyonesWatching: [MediaItem] = []
    private(set) var topSeries: [MediaItem] = []
    private(set) var topFilms: [MediaItem] = []
    private(set) var isLoading = false
    private(set) var didFail = false

    @ObservationIgnored private var hasLoaded = false
    private let library: NFLibrary

    init(library: NFLibrary) {
        self.library = library
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        hasLoaded = true
        isLoading = true
        didFail = false

        let tomorrow = NF.tmdbDay(offsetDays: 1)
        let horizon = NF.tmdbDay(offsetDays: 120)

        async let upcomingMovies = try? NFCatalogService.list(
            path: "/3/movie/upcoming",
            query: ["region": "US"],
            fallbackType: .movie
        )
        async let upcomingMoviesPage2 = try? NFCatalogService.list(
            path: "/3/movie/upcoming",
            query: ["region": "US", "page": "2"],
            fallbackType: .movie
        )
        async let upcomingSeries = try? NFCatalogService.list(
            path: "/3/discover/tv",
            query: [
                "first_air_date.gte": tomorrow,
                "first_air_date.lte": horizon,
                "sort_by": "popularity.desc",
                "without_genres": "10763,10767,10766,10764"
            ],
            fallbackType: .tv
        )
        async let trending = try? NFCatalogService.list(path: "/3/trending/all/day", fallbackType: nil)
        async let series = try? NFCatalogService.list(path: "/3/trending/tv/day", fallbackType: .tv)
        async let films = try? NFCatalogService.list(path: "/3/trending/movie/day", fallbackType: .movie)

        let startOfTomorrow = Calendar.current.startOfDay(for: Date()).addingTimeInterval(24 * 60 * 60)
        let upcomingPool = ((await upcomingMovies) ?? []) + ((await upcomingMoviesPage2) ?? []) + ((await upcomingSeries) ?? [])

        var seen = Set<String>()
        comingSoon = upcomingPool
            .compactMap { item -> Upcoming? in
                guard item.posterPath != nil,
                      item.backdropPath != nil,
                      !item.overview.isEmpty,
                      let date = item.releaseDateValue,
                      date >= startOfTomorrow,
                      seen.insert(item.nfKey).inserted else {
                    return nil
                }
                return Upcoming(item: item, date: date)
            }
            .sorted { $0.date < $1.date }
            .prefix(24)
            .map { $0 }

        everyonesWatching = Array(((await trending) ?? []).filter { $0.isBrowsable && $0.backdropPath != nil }.prefix(10))
        topSeries = Array(((await series) ?? []).filter(\.isBrowsable).prefix(10))
        topFilms = Array(((await films) ?? []).filter(\.isBrowsable).prefix(10))

        library.recordRanks(topSeries, listName: "Series Today")
        library.recordRanks(topFilms, listName: "Films Today")

        isLoading = false
        didFail = comingSoon.isEmpty && everyonesWatching.isEmpty && topSeries.isEmpty && topFilms.isEmpty
        if didFail {
            hasLoaded = false
        }
    }
}
