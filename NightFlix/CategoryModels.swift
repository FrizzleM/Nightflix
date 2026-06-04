import Foundation
import Observation

struct GenreListResponse: Decodable {
    let genres: [Genre]
}

enum CategoryContentType: String, CaseIterable, Identifiable, Hashable {
    case movies = "Movies"
    case tvSeries = "TV Series"

    var id: String { rawValue }

    var mediaType: MediaType {
        switch self {
        case .movies:
            return .movie
        case .tvSeries:
            return .tv
        }
    }

    var sectionTitle: String {
        switch self {
        case .movies:
            return "Movie Genres"
        case .tvSeries:
            return "TV Genres"
        }
    }
}

struct CategorySelection: Identifiable, Hashable {
    let contentType: CategoryContentType
    let genre: Genre

    var id: String {
        "\(contentType.id)-\(genre.id)"
    }
}

@Observable
@MainActor
final class CategoriesViewModel {
    var movieGenres: [Genre] = []
    var tvGenres: [Genre] = []
    var isLoadingMovieGenres = false
    var isLoadingTVGenres = false
    var movieGenresErrorMessage: String?
    var tvGenresErrorMessage: String?

    private let service: TMDBService
    private var hasLoaded = false
    private var activeRequestID: UUID?

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    func reload() async {
        let requestID = UUID()
        activeRequestID = requestID
        isLoadingMovieGenres = true
        isLoadingTVGenres = true
        movieGenresErrorMessage = nil
        tvGenresErrorMessage = nil

        async let movieGenreResult = fetchMovieGenres()
        async let tvGenreResult = fetchTVGenres()

        let movieResult = await movieGenreResult
        let tvResult = await tvGenreResult
        guard activeRequestID == requestID else { return }

        movieGenres = movieResult.genres
        movieGenresErrorMessage = movieResult.errorMessage
        isLoadingMovieGenres = false

        tvGenres = tvResult.genres
        tvGenresErrorMessage = tvResult.errorMessage
        isLoadingTVGenres = false
        activeRequestID = nil
    }

    func genres(for contentType: CategoryContentType) -> [Genre] {
        switch contentType {
        case .movies:
            return movieGenres
        case .tvSeries:
            return tvGenres
        }
    }

    func isLoading(_ contentType: CategoryContentType) -> Bool {
        switch contentType {
        case .movies:
            return isLoadingMovieGenres
        case .tvSeries:
            return isLoadingTVGenres
        }
    }

    func errorMessage(for contentType: CategoryContentType) -> String? {
        switch contentType {
        case .movies:
            return movieGenresErrorMessage
        case .tvSeries:
            return tvGenresErrorMessage
        }
    }

    private func fetchMovieGenres() async -> (genres: [Genre], errorMessage: String?) {
        do {
            return (try await service.movieGenres(), nil)
        } catch is CancellationError {
            return (movieGenres, nil)
        } catch {
            return ([], "Movie genres could not be loaded. Please try again.")
        }
    }

    private func fetchTVGenres() async -> (genres: [Genre], errorMessage: String?) {
        do {
            return (try await service.tvGenres(), nil)
        } catch is CancellationError {
            return (tvGenres, nil)
        } catch {
            return ([], "TV genres could not be loaded. Please try again.")
        }
    }
}

@Observable
@MainActor
final class CategoryDetailViewModel {
    var items: [MediaItem] = []
    var isLoading = false
    var errorMessage: String?
    var didLoad = false

    private let service: TMDBService
    private var loadedKey: String?
    private var activeRequestID: UUID?

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    func loadIfNeeded(selection: CategorySelection) async {
        let key = selection.id
        guard loadedKey != key else { return }
        await reload(selection: selection)
    }

    func reload(selection: CategorySelection) async {
        let requestID = UUID()
        activeRequestID = requestID
        loadedKey = selection.id
        isLoading = true
        errorMessage = nil
        didLoad = false
        items = []

        do {
            switch selection.contentType {
            case .movies:
                let movies = try await service.discoverMovies(genreId: selection.genre.id)
                guard activeRequestID == requestID else { return }

                items = movies.map { movie in
                    MediaItem(
                        id: movie.id,
                        mediaType: MediaType.movie.rawValue,
                        title: movie.title,
                        name: nil,
                        overview: movie.overview,
                        releaseDate: movie.releaseDate,
                        posterPath: movie.posterPath,
                        backdropPath: movie.backdropPath
                    )
                }
            case .tvSeries:
                let series = try await service.discoverTVSeries(genreId: selection.genre.id)
                guard activeRequestID == requestID else { return }

                items = series.map { tv in
                    MediaItem(
                        id: tv.id,
                        mediaType: MediaType.tv.rawValue,
                        title: nil,
                        name: tv.name,
                        overview: tv.overview,
                        firstAirDate: tv.firstAirDate,
                        posterPath: tv.posterPath,
                        backdropPath: tv.backdropPath
                    )
                }
            }
            didLoad = true
        } catch is CancellationError {
        } catch {
            guard activeRequestID == requestID else { return }

            errorMessage = "This category could not be loaded. Please try again."
            didLoad = true
        }

        guard activeRequestID == requestID else { return }

        isLoading = false
        activeRequestID = nil
    }
}
