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

        async let featuredHeroTask = loadFeaturedHeroItem()
        async let trendingTask = loadTrending()
        async let popularMoviesTask = loadPopularMovies()
        async let popularSeriesTask = loadPopularSeries()
        async let topRatedMoviesTask = loadTopRatedMovies()
        async let topRatedSeriesTask = loadTopRatedSeries()

        featuredHeroItem = await featuredHeroTask
        isLoadingFeaturedHero = false
        trending = await trendingTask
        popularMovies = await popularMoviesTask
        popularSeries = await popularSeriesTask
        topRatedMovies = await topRatedMoviesTask
        topRatedSeries = await topRatedSeriesTask
    }

    private func loadFeaturedHeroItem() async -> MediaItem? {
        do {
            return try await service.fetchFeaturedHeroItem()
        } catch is CancellationError {
            return featuredHeroItem
        } catch {
            return nil
        }
    }

    private func loadTrending() async -> FeedSection {
        do {
            let items = try await service.trendingAllWeek().compactMap(FeedItem.init(trendingResult:))
            return section(from: items)
        } catch is CancellationError {
            return cancelledSection(from: trending)
        } catch {
            return FeedSection(errorMessage: error.localizedDescription)
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
}
