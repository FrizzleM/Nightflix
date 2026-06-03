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
            isLoading = false
            errorMessage = nil
            results = []
            didCompleteSearch = false
            return
        }

        errorMessage = nil
        isLoading = true
        didCompleteSearch = false

        searchTask = Task { [service] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()

                let searchResults = try await service.searchMulti(query: trimmedQuery)
                try Task.checkCancellation()

                results = searchResults
                errorMessage = nil
                didCompleteSearch = true
            } catch is CancellationError {
                return
            } catch {
                results = []
                errorMessage = error.localizedDescription
                didCompleteSearch = true
            }

            isLoading = false
        }
    }
}
