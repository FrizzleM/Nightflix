import Foundation
import Observation

struct FeedSection: Equatable {
    var items: [FeedItem] = []
    var isLoading = false
    var errorMessage: String?
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

    private let service: TMDBService
    private var hasLoaded = false

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
        featuredHeroItem = trendingResult.featuredHeroItem
        isLoadingFeaturedHero = false
        trending = trendingResult.section
        popularMovies = await popularMoviesTask
        popularSeries = await popularSeriesTask
        topRatedMovies = await topRatedMoviesTask
        topRatedSeries = await topRatedSeriesTask
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
}
