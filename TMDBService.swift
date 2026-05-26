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
    private static let sharedURLCache = URLCache(
        memoryCapacity: 50 * 1024 * 1024,
        diskCapacity: 200 * 1024 * 1024,
        diskPath: "NightFlixTMDBURLCache"
    )
    private static let responseCache = TMDBResponseCache(urlCache: sharedURLCache)
    private static let sharedSession: URLSession = {
        URLCache.shared = sharedURLCache

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = sharedURLCache
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 6

        return URLSession(configuration: configuration)
    }()

    private let session: URLSession

    init(session: URLSession = TMDBService.sharedSession) {
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
        do {
            data = try await Self.responseCache.data(
                for: Self.cacheKey(for: request),
                request: request,
                session: session,
                ttl: Self.cacheTTL(for: path)
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as TMDBServiceError {
            throw error
        } catch {
            throw TMDBServiceError.networkFailure(error)
        }

        do {
            return try JSONDecoder().decode(Result.self, from: data)
        } catch {
            throw TMDBServiceError.decodingFailed(error)
        }
    }

    private static func cacheKey(for request: URLRequest) -> String {
        "\(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")"
    }

    private static func cacheTTL(for path: String) -> TimeInterval {
        switch path {
        case _ where path.contains("/search/"):
            return 5 * 60
        case "/3/genre/movie/list", "/3/genre/tv/list":
            return 24 * 60 * 60
        case "/3/trending/all/week",
             "/3/movie/popular",
             "/3/tv/popular",
             "/3/movie/top_rated",
             "/3/tv/top_rated":
            return 15 * 60
        case _ where path.contains("/discover/"):
            return 30 * 60
        default:
            return 6 * 60 * 60
        }
    }
}

private actor TMDBResponseCache {
    private typealias NetworkResponse = (data: Data, response: URLResponse)

    private struct Entry {
        let data: Data
        let expiresAt: Date
        var lastAccessed: Date
    }

    private var entries: [String: Entry] = [:]
    private var inFlightTasks: [String: Task<NetworkResponse, Error>] = [:]
    private let urlCache: URLCache
    private let maxEntries = 200
    private let maxBytes = 32 * 1024 * 1024
    private let diskExpirationUserInfoKey = "NightFlixCacheExpiresAt"

    init(urlCache: URLCache) {
        self.urlCache = urlCache
    }

    func data(
        for key: String,
        request: URLRequest,
        session: URLSession,
        ttl: TimeInterval
    ) async throws -> Data {
        let now = Date()

        if var entry = entries[key] {
            if entry.expiresAt > now {
                entry.lastAccessed = now
                entries[key] = entry
                return entry.data
            }

            entries[key] = nil
        }

        if let diskData = cachedDiskData(for: request, key: key, now: now) {
            return diskData
        }

        if let inFlightTask = inFlightTasks[key] {
            return try await inFlightTask.value.data
        }

        let task = Task<NetworkResponse, Error> {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TMDBServiceError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw TMDBServiceError.requestFailed(httpResponse.statusCode)
            }

            return (data, response)
        }

        inFlightTasks[key] = task

        do {
            let networkResponse = try await task.value
            let completedAt = Date()
            let expiresAt = completedAt.addingTimeInterval(ttl)

            inFlightTasks[key] = nil
            entries[key] = Entry(
                data: networkResponse.data,
                expiresAt: expiresAt,
                lastAccessed: completedAt
            )
            storeDiskData(
                networkResponse.data,
                response: networkResponse.response,
                request: request,
                expiresAt: expiresAt
            )
            prune(now: completedAt)

            return networkResponse.data
        } catch {
            inFlightTasks[key] = nil
            throw error
        }
    }

    private func prune(now: Date) {
        entries = entries.filter { $0.value.expiresAt > now }

        guard entries.count > maxEntries || totalBytes > maxBytes else {
            return
        }

        let keysByLastAccess = entries
            .sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            .map(\.key)

        for key in keysByLastAccess {
            guard entries.count > maxEntries || totalBytes > maxBytes else {
                break
            }

            entries[key] = nil
        }
    }

    private var totalBytes: Int {
        entries.values.reduce(0) { $0 + $1.data.count }
    }

    private func cachedDiskData(for request: URLRequest, key: String, now: Date) -> Data? {
        guard let cachedResponse = urlCache.cachedResponse(for: request) else {
            return nil
        }

        guard let expiresAt = cachedResponse.userInfo?[diskExpirationUserInfoKey] as? Date,
              expiresAt > now else {
            urlCache.removeCachedResponse(for: request)
            return nil
        }

        entries[key] = Entry(
            data: cachedResponse.data,
            expiresAt: expiresAt,
            lastAccessed: now
        )
        prune(now: now)

        return cachedResponse.data
    }

    private func storeDiskData(
        _ data: Data,
        response: URLResponse,
        request: URLRequest,
        expiresAt: Date
    ) {
        let cachedResponse = CachedURLResponse(
            response: response,
            data: data,
            userInfo: [diskExpirationUserInfoKey: expiresAt],
            storagePolicy: .allowed
        )
        urlCache.storeCachedResponse(cachedResponse, for: request)
    }
}
