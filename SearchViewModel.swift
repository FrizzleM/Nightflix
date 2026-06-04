import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    var query = ""
    var results: [MediaSearchResult] = []
    var isLoading = false
    var errorMessage: String?
    var didCompleteSearch = false

    private let service: TMDBService
    private var searchTask: Task<Void, Never>?
    private var searchRequestID: UUID?
    private var lastCompletedQuery: String?
    private var lastCompletedResults: [MediaSearchResult] = []

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    var hasResults: Bool {
        !results.isEmpty
    }

    var hasActiveQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateQuery(_ newQuery: String) {
        query = newQuery
        scheduleSearch()
    }

    func clearSearch() {
        searchTask?.cancel()
        searchRequestID = nil
        query = ""
        results = []
        isLoading = false
        errorMessage = nil
        didCompleteSearch = false
    }

    func scheduleSearch() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchRequestID = nil
            isLoading = false
            errorMessage = nil
            results = []
            didCompleteSearch = false
            return
        }

        if trimmedQuery == lastCompletedQuery {
            searchRequestID = nil
            results = lastCompletedResults
            errorMessage = nil
            isLoading = false
            didCompleteSearch = true
            return
        }

        let requestID = UUID()
        searchRequestID = requestID
        errorMessage = nil
        isLoading = true
        didCompleteSearch = false

        searchTask = Task { [service] in
            defer {
                if searchRequestID == requestID {
                    isLoading = false
                    searchRequestID = nil
                }
            }

            do {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()

                let searchResults = try await service.searchMulti(query: trimmedQuery)
                try Task.checkCancellation()
                guard searchRequestID == requestID else { return }

                results = searchResults
                lastCompletedQuery = trimmedQuery
                lastCompletedResults = searchResults
                errorMessage = nil
                didCompleteSearch = true
            } catch is CancellationError {
                return
            } catch {
                guard searchRequestID == requestID else { return }

                results = []
                errorMessage = error.localizedDescription
                didCompleteSearch = true
            }
        }
    }
}
