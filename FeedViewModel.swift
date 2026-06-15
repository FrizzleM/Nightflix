import Foundation
import Observation

struct FeedSection: Equatable {
    var items: [FeedItem] = []
    var isLoading = false
    var errorMessage: String?
}

/// A single "Because you watched <seedTitle>" rail of recommendations.
struct PersonalizedRow: Identifiable, Equatable {
    let id: String
    let seedTitle: String
    let items: [FeedItem]
}

@Observable
@MainActor
final class FeedViewModel {
    var trending = FeedSection()
    var popularMovies = FeedSection()
    var popularSeries = FeedSection()
    var topRatedMovies = FeedSection()
    var topRatedSeries = FeedSection()
    var featuredHeroItem: MediaItem?
    var isLoadingFeaturedHero = false
    var personalizedRows: [PersonalizedRow] = []
    var isLoadingPersonalizedRows = false

    private static let maxPersonalizedSeeds = 4
    private static let minPersonalizedRowItems = 4
    private static let maxPersonalizedRowItems = 16

    private let service: TMDBService
    private var hasLoaded = false
    private var activeRequestID: UUID?
    private var activePersonalizedRequestID: UUID?
    private var loadedSeedSignature = ""

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadAllSections()
    }

    func refresh() async {
        await loadAllSections()
    }

    private func loadAllSections() async {
        let requestID = UUID()
        activeRequestID = requestID
        trending.isLoading = true
        popularMovies.isLoading = true
        popularSeries.isLoading = true
        topRatedMovies.isLoading = true
        topRatedSeries.isLoading = true
        isLoadingFeaturedHero = true

        async let trendingTask = loadTrending()
        async let popularMoviesTask = loadPopularMovies()
        async let popularSeriesTask = loadPopularSeries()
        async let topRatedMoviesTask = loadTopRatedMovies()
        async let topRatedSeriesTask = loadTopRatedSeries()

        let trendingResult = await trendingTask
        guard activeRequestID == requestID else { return }

        featuredHeroItem = trendingResult.featuredHeroItem
        isLoadingFeaturedHero = false
        trending = trendingResult.section

        let popularMoviesResult = await popularMoviesTask
        guard activeRequestID == requestID else { return }
        popularMovies = popularMoviesResult

        let popularSeriesResult = await popularSeriesTask
        guard activeRequestID == requestID else { return }
        popularSeries = popularSeriesResult

        let topRatedMoviesResult = await topRatedMoviesTask
        guard activeRequestID == requestID else { return }
        topRatedMovies = topRatedMoviesResult

        let topRatedSeriesResult = await topRatedSeriesTask
        guard activeRequestID == requestID else { return }
        topRatedSeries = topRatedSeriesResult

        activeRequestID = nil
        prefetchStartupImages()
    }

    private func loadTrending() async -> (section: FeedSection, featuredHeroItem: MediaItem?) {
        do {
            let results = try await service.trendingAllWeek()
            let items = results.compactMap(FeedItem.init(trendingResult:))
            return (section(from: items), featuredHeroItem(from: results))
        } catch is CancellationError {
            return (cancelledSection(from: trending), featuredHeroItem)
        } catch {
            return (FeedSection(errorMessage: error.localizedDescription), nil)
        }
    }

    private func loadPopularMovies() async -> FeedSection {
        do {
            let items = try await service.popularMovies().map(FeedItem.init(movie:))
            return section(from: items)
        } catch is CancellationError {
            return cancelledSection(from: popularMovies)
        } catch {
            return FeedSection(errorMessage: error.localizedDescription)
        }
    }

    private func loadPopularSeries() async -> FeedSection {
        do {
            let items = try await service.popularTVSeries().map(FeedItem.init(tv:))
            return section(from: items)
        } catch is CancellationError {
            return cancelledSection(from: popularSeries)
        } catch {
            return FeedSection(errorMessage: error.localizedDescription)
        }
    }

    private func loadTopRatedMovies() async -> FeedSection {
        do {
            let items = try await service.topRatedMovies().map(FeedItem.init(movie:))
            return section(from: items)
        } catch is CancellationError {
            return cancelledSection(from: topRatedMovies)
        } catch {
            return FeedSection(errorMessage: error.localizedDescription)
        }
    }

    private func loadTopRatedSeries() async -> FeedSection {
        do {
            let items = try await service.topRatedTVSeries().map(FeedItem.init(tv:))
            return section(from: items)
        } catch is CancellationError {
            return cancelledSection(from: topRatedSeries)
        } catch {
            return FeedSection(errorMessage: error.localizedDescription)
        }
    }

    // MARK: - Personalized "Because you watched" rows

    private struct PersonalizationSeed {
        let id: Int
        let type: WatchType
        let title: String

        var key: String { "\(type.rawValue)-\(id)" }
    }

    /// Builds (or refreshes) the personalized rails from the user's watch history.
    /// Seeds are the most-recently watched distinct titles; each produces a row of
    /// TMDB recommendations, de-duplicated globally and stripped of already-watched
    /// titles. Rows are revealed progressively as each seed's data arrives.
    func loadPersonalizedRows(from history: [WatchItem], force: Bool = false) async {
        let seeds = personalizationSeeds(from: history)

        guard !seeds.isEmpty else {
            activePersonalizedRequestID = nil
            loadedSeedSignature = ""
            personalizedRows = []
            isLoadingPersonalizedRows = false
            return
        }

        let signature = seeds.map(\.key).joined(separator: "|")
        if !force, signature == loadedSeedSignature {
            return
        }

        let requestID = UUID()
        activePersonalizedRequestID = requestID
        isLoadingPersonalizedRows = true

        let watchedKeys = Set(
            history.compactMap { item -> String? in
                guard let intId = Int(item.tmdbId) else { return nil }
                return Self.itemKey(type: item.type, id: intId)
            }
        )

        var seenIDs = Set<Int>()
        var rows: [PersonalizedRow] = []

        for seed in seeds {
            let recommendations = await loadRecommendations(for: seed)
            guard activePersonalizedRequestID == requestID else { return }

            var rowItems: [FeedItem] = []
            var rowItemIDs = Set<Int>()
            for item in recommendations {
                guard item.id != seed.id, item.posterPath != nil else { continue }
                guard !watchedKeys.contains(Self.itemKey(type: item.type, id: item.id)) else { continue }
                guard !seenIDs.contains(item.id), rowItemIDs.insert(item.id).inserted else { continue }

                rowItems.append(item)
                if rowItems.count >= Self.maxPersonalizedRowItems { break }
            }

            guard rowItems.count >= Self.minPersonalizedRowItems else { continue }

            seenIDs.formUnion(rowItemIDs)
            rows.append(PersonalizedRow(id: seed.key, seedTitle: seed.title, items: rowItems))
            personalizedRows = rows
        }

        guard activePersonalizedRequestID == requestID else { return }

        personalizedRows = rows
        loadedSeedSignature = signature
        isLoadingPersonalizedRows = false
        activePersonalizedRequestID = nil
    }

    private func personalizationSeeds(from history: [WatchItem]) -> [PersonalizationSeed] {
        var seeds: [PersonalizationSeed] = []
        var seenKeys = Set<String>()

        for item in history {
            guard let intId = Int(item.tmdbId) else { continue }
            let seed = PersonalizationSeed(id: intId, type: item.type, title: item.title)
            guard seenKeys.insert(seed.key).inserted else { continue }

            seeds.append(seed)
            if seeds.count >= Self.maxPersonalizedSeeds { break }
        }

        return seeds
    }

    private func loadRecommendations(for seed: PersonalizationSeed) async -> [FeedItem] {
        do {
            let results: [MediaRecommendationItem]
            switch seed.type {
            case .movie:
                results = try await service.movieRecommendations(movieId: seed.id)
            case .tv:
                results = try await service.tvRecommendations(seriesId: seed.id)
            }

            return results.map { FeedItem(recommendation: $0, fallbackType: seed.type) }
        } catch {
            return []
        }
    }

    private static func itemKey(type: WatchType, id: Int) -> String {
        "\(type.rawValue)-\(id)"
    }

    private func section(from items: [FeedItem]) -> FeedSection {
        if items.isEmpty {
            return FeedSection(errorMessage: "TMDB returned no items for this section.")
        }

        return FeedSection(items: items)
    }

    private func cancelledSection(from section: FeedSection) -> FeedSection {
        FeedSection(items: section.items, errorMessage: section.errorMessage)
    }

    private func featuredHeroItem(from results: [TMDBTrendingResult]) -> MediaItem? {
        let mediaItems = results.compactMap { result -> MediaItem? in
            guard result.mediaType == "movie" || result.mediaType == "tv" else {
                return nil
            }

            return MediaItem(
                id: result.id,
                mediaType: result.mediaType,
                title: result.title,
                name: result.name,
                overview: result.overview,
                releaseDate: result.releaseDate,
                firstAirDate: result.firstAirDate,
                posterPath: result.posterPath,
                backdropPath: result.backdropPath
            )
        }

        return mediaItems.first { $0.backdropPath != nil } ?? mediaItems.first
    }

    private func prefetchStartupImages() {
        let urls = startupImageURLs()
        guard !urls.isEmpty else { return }

        Task.detached(priority: .utility) {
            await StartupImagePrefetcher.prefetch(urls)
        }
    }

    private func startupImageURLs() -> [URL] {
        var urls: [URL] = []
        var seenURLs = Set<URL>()

        func append(_ url: URL?) {
            guard let url, seenURLs.insert(url).inserted else { return }
            urls.append(url)
        }

        append(featuredHeroItem?.backdropURL ?? featuredHeroItem?.posterURL)

        for item in trending.items.prefix(6) {
            append(item.posterURL)
        }

        for section in [popularMovies, popularSeries, topRatedMovies, topRatedSeries] {
            for item in section.items.prefix(2) {
                append(item.posterURL)
            }
        }

        return urls
    }
}

private enum StartupImagePrefetcher {
    static func prefetch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 15

                    _ = try? await URLSession.shared.data(for: request)
                }
            }
        }
    }
}
