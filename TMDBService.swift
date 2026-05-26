import Foundation

enum TMDBServiceError: LocalizedError {
    case missingBearerToken
    case invalidURL
    case networkFailure(Error)
    case invalidResponse
    case requestFailed(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingBearerToken:
            return "Add your TMDB bearer token in TMDBConfig before loading TMDB data."
        case .invalidURL:
            return "The TMDB URL could not be created."
        case .networkFailure(let error):
            return "Network request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "TMDB returned an invalid response."
        case .requestFailed(let statusCode):
            return "TMDB request failed with status code \(statusCode)."
        case .decodingFailed:
            return "TMDB returned data the app could not read."
        }
    }
}

struct TMDBService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchMovies(query: String) async throws -> [TMDBMovieResult] {
        let response: TMDBSearchResponse<TMDBMovieResult> = try await requestSearch(
            path: "/3/search/movie",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )
        return response.results
    }

    func searchTVSeries(query: String) async throws -> [TMDBTVResult] {
        let response: TMDBSearchResponse<TMDBTVResult> = try await requestSearch(
            path: "/3/search/tv",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )
        return response.results
    }

    func searchMulti(query: String) async throws -> [MediaSearchResult] {
        let response: TMDBSearchResponse<MediaSearchResult> = try await requestSearch(
            path: "/3/search/multi",
            queryItems: [URLQueryItem(name: "query", value: query)]
        )
        return response.results.filter { $0.isMovie || $0.isTVSeries }
    }

    func trendingAllWeek() async throws -> [TMDBTrendingResult] {
        let response: TMDBSearchResponse<TMDBTrendingResult> = try await requestSearch(path: "/3/trending/all/week")
        return response.results
    }

    func fetchFeaturedHeroItem() async throws -> MediaItem? {
        let response: TMDBSearchResponse<MediaItem> = try await requestSearch(path: "/3/trending/all/week")
        let validResults = response.results.filter { $0.isMovie || $0.isTVSeries }
        let resultsWithBackdrop = validResults.filter { $0.backdropPath != nil }

        if let featuredItem = resultsWithBackdrop.prefix(5).first {
            return featuredItem
        }

        return validResults.first
    }

    func popularMovies() async throws -> [TMDBMovieResult] {
        let response: TMDBSearchResponse<TMDBMovieResult> = try await requestSearch(path: "/3/movie/popular")
        return response.results
    }

    func popularTVSeries() async throws -> [TMDBTVResult] {
        let response: TMDBSearchResponse<TMDBTVResult> = try await requestSearch(path: "/3/tv/popular")
        return response.results
    }

    func topRatedMovies() async throws -> [TMDBMovieResult] {
        let response: TMDBSearchResponse<TMDBMovieResult> = try await requestSearch(path: "/3/movie/top_rated")
        return response.results
    }

    func topRatedTVSeries() async throws -> [TMDBTVResult] {
        let response: TMDBSearchResponse<TMDBTVResult> = try await requestSearch(path: "/3/tv/top_rated")
        return response.results
    }

    func movieGenres() async throws -> [Genre] {
        let response: GenreListResponse = try await requestDecoded(path: "/3/genre/movie/list")
        return response.genres
    }

    func tvGenres() async throws -> [Genre] {
        let response: GenreListResponse = try await requestDecoded(path: "/3/genre/tv/list")
        return response.genres
    }

    func discoverMovies(genreId: Int) async throws -> [TMDBMovieResult] {
        let response: TMDBSearchResponse<TMDBMovieResult> = try await requestSearch(
            path: "/3/discover/movie",
            queryItems: [
                URLQueryItem(name: "with_genres", value: String(genreId)),
                URLQueryItem(name: "sort_by", value: "popularity.desc")
            ]
        )
        return response.results
    }

    func discoverTVSeries(genreId: Int) async throws -> [TMDBTVResult] {
        let response: TMDBSearchResponse<TMDBTVResult> = try await requestSearch(
            path: "/3/discover/tv",
            queryItems: [
                URLQueryItem(name: "with_genres", value: String(genreId)),
                URLQueryItem(name: "sort_by", value: "popularity.desc")
            ]
        )
        return response.results
    }

    func tvSeriesDetails(seriesId: Int) async throws -> TVSeriesDetails {
        try await requestDecoded(path: "/3/tv/\(seriesId)")
    }

    func seasonDetails(seriesId: Int, seasonNumber: Int) async throws -> SeasonDetails {
        try await requestDecoded(path: "/3/tv/\(seriesId)/season/\(seasonNumber)")
    }

    func fetchMovieDetail(movieId: Int) async throws -> MovieDetail {
        try await requestDecoded(
            path: "/3/movie/\(movieId)",
            queryItems: [
                URLQueryItem(
                    name: "append_to_response",
                    value: "credits,videos,images,release_dates,similar,recommendations"
                )
            ]
        )
    }

    func fetchTVSeriesDetail(seriesId: Int) async throws -> TVSeriesDetail {
        try await requestDecoded(
            path: "/3/tv/\(seriesId)",
            queryItems: [
                URLQueryItem(
                    name: "append_to_response",
                    value: "credits,videos,images,content_ratings,similar,recommendations"
                )
            ]
        )
    }

    func fetchSeasonDetail(seriesId: Int, seasonNumber: Int) async throws -> SeasonDetail {
        try await requestDecoded(path: "/3/tv/\(seriesId)/season/\(seasonNumber)")
    }

    private func requestSearch<Result: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> TMDBSearchResponse<Result> {
        try await requestDecoded(path: path, queryItems: queryItems)
    }

    private func requestDecoded<Result: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> Result {
        guard TMDBConfig.hasConfiguredBearerToken else {
            throw TMDBServiceError.missingBearerToken
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.themoviedb.org"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TMDBServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(TMDBConfig.bearerToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw TMDBServiceError.networkFailure(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TMDBServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw TMDBServiceError.requestFailed(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(Result.self, from: data)
        } catch {
            throw TMDBServiceError.decodingFailed(error)
        }
    }
}
