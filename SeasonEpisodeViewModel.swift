import Foundation
import Observation

@Observable
@MainActor
final class SeasonEpisodeViewModel {
    var seriesDetails: TVSeriesDetails?
    var selectedSeason: Season?
    var seasonDetails: SeasonDetails?
    var isLoadingSeries = false
    var isLoadingSeason = false
    var seriesErrorMessage: String?
    var seasonErrorMessage: String?

    private let service: TMDBService
    private var sortedSeasons: [Season] = []
    private var sortedEpisodes: [Episode] = []
    private var seasonDetailsCache: [Int: SeasonDetails] = [:]
    private var seriesRequestID: UUID?
    private var seasonRequestID: UUID?

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    var seasons: [Season] {
        sortedSeasons
    }

    var episodes: [Episode] {
        sortedEpisodes
    }

    func loadSeriesIfNeeded(seriesId: Int) async {
        guard seriesDetails?.id != seriesId else { return }
        await loadSeries(seriesId: seriesId)
    }

    func loadSeries(seriesId: Int) async {
        let requestID = UUID()
        seriesRequestID = requestID
        isLoadingSeries = true
        seriesErrorMessage = nil
        seasonErrorMessage = nil
        selectedSeason = nil
        seasonDetails = nil
        sortedSeasons = []
        sortedEpisodes = []
        seasonDetailsCache = [:]

        do {
            let details = try await service.tvSeriesDetails(seriesId: seriesId)
            guard seriesRequestID == requestID else { return }

            seriesDetails = details
            sortedSeasons = details.seasons.sorted { lhs, rhs in
                lhs.seasonNumber < rhs.seasonNumber
            }
            seriesErrorMessage = details.seasons.isEmpty ? "TMDB returned no seasons for this series." : nil
        } catch is CancellationError {
            guard seriesRequestID == requestID else { return }
        } catch {
            guard seriesRequestID == requestID else { return }

            seriesDetails = nil
            sortedSeasons = []
            seriesErrorMessage = error.localizedDescription
        }

        guard seriesRequestID == requestID else { return }

        isLoadingSeries = false
        seriesRequestID = nil
    }

    func selectSeason(_ season: Season, seriesId: Int) async {
        let requestID = UUID()
        seasonRequestID = requestID
        selectedSeason = season
        seasonDetails = nil
        sortedEpisodes = []
        seasonErrorMessage = nil

        if let cachedDetails = seasonDetailsCache[season.seasonNumber] {
            seasonDetails = cachedDetails
            sortedEpisodes = cachedDetails.episodes.sorted { lhs, rhs in
                lhs.episodeNumber < rhs.episodeNumber
            }
            isLoadingSeason = false
            seasonRequestID = nil
            return
        }

        isLoadingSeason = true

        do {
            let details = try await service.seasonDetails(seriesId: seriesId, seasonNumber: season.seasonNumber)
            guard seasonRequestID == requestID else { return }

            seasonDetailsCache[season.seasonNumber] = details
            seasonDetails = details
            sortedEpisodes = details.episodes.sorted { lhs, rhs in
                lhs.episodeNumber < rhs.episodeNumber
            }
            seasonErrorMessage = details.episodes.isEmpty ? "TMDB returned no episodes for this season." : nil
        } catch is CancellationError {
            guard seasonRequestID == requestID else { return }
        } catch {
            guard seasonRequestID == requestID else { return }

            seasonDetails = nil
            sortedEpisodes = []
            seasonErrorMessage = error.localizedDescription
        }

        guard seasonRequestID == requestID else { return }

        isLoadingSeason = false
        seasonRequestID = nil
    }
}
