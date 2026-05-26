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

    init() {
        self.service = TMDBService()
    }

    init(service: TMDBService) {
        self.service = service
    }

    var seasons: [Season] {
        seriesDetails?.seasons.sorted { lhs, rhs in
            lhs.seasonNumber < rhs.seasonNumber
        } ?? []
    }

    var episodes: [Episode] {
        seasonDetails?.episodes.sorted { lhs, rhs in
            lhs.episodeNumber < rhs.episodeNumber
        } ?? []
    }

    func loadSeriesIfNeeded(seriesId: Int) async {
        guard seriesDetails?.id != seriesId else { return }
        await loadSeries(seriesId: seriesId)
    }

    func loadSeries(seriesId: Int) async {
        isLoadingSeries = true
        seriesErrorMessage = nil
        seasonErrorMessage = nil
        selectedSeason = nil
        seasonDetails = nil

        do {
            let details = try await service.tvSeriesDetails(seriesId: seriesId)
            seriesDetails = details
            seriesErrorMessage = details.seasons.isEmpty ? "TMDB returned no seasons for this series." : nil
        } catch {
            seriesDetails = nil
            seriesErrorMessage = error.localizedDescription
        }

        isLoadingSeries = false
    }

    func selectSeason(_ season: Season, seriesId: Int) async {
        selectedSeason = season
        seasonDetails = nil
        seasonErrorMessage = nil
        isLoadingSeason = true

        do {
            let details = try await service.seasonDetails(seriesId: seriesId, seasonNumber: season.seasonNumber)
            seasonDetails = details
            seasonErrorMessage = details.episodes.isEmpty ? "TMDB returned no episodes for this season." : nil
        } catch {
            seasonDetails = nil
            seasonErrorMessage = error.localizedDescription
        }

        isLoadingSeason = false
    }
}
