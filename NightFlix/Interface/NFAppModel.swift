import Foundation
import Observation
import SwiftUI

/// App-wide state for the interface: the existing history/progress managers plus the
/// new library, feed and New & Hot models. Created once by the root view and passed to
/// every presented screen.
@Observable
final class NFAppModel {
    let history = WatchHistoryManager()
    let continueWatching = ContinueWatchingManager()
    let library: NFLibrary
    let feed: NFFeedModel
    let newHot: NFNewHotModel

    /// The full-screen option picker (categories, seasons) shown over the tab bar.
    var picker: NFPickerRequest?

    init() {
        let library = NFLibrary()
        self.library = library
        feed = NFFeedModel(library: library)
        newHot = NFNewHotModel(library: library)
    }

    // MARK: - Progress

    func continueEntry(for media: MediaItem) -> ContinueWatchingItem? {
        continueWatching.items.first { $0.type == media.nfType && $0.tmdbId == String(media.id) }
    }

    /// What "Resume" means for a title: its tracked episode and how far in it is.
    func resumeState(for media: MediaItem) -> NFResumeState? {
        guard let entry = continueEntry(for: media) else { return nil }
        return NFResumeState(entry: entry)
    }

    // MARK: - Playback

    /// A play item for a title: movies resume where they stopped; series resume their
    /// tracked episode or start at S1 E1.
    func watchItem(for media: MediaItem) -> WatchItem? {
        if media.isMovie {
            return movieItem(id: media.id, title: media.displayTitle, posterPath: media.posterPath)
        }

        let tracked = continueEntry(for: media)
        return episodeItem(
            seriesId: media.id,
            seriesName: media.displayTitle,
            posterPath: media.posterPath,
            season: tracked?.season ?? 1,
            episode: tracked?.episode ?? 1,
            episodeName: tracked?.episodeName
        )
    }

    func movieItem(id: Int, title: String, posterPath: String?) -> WatchItem? {
        let resume = continueWatching.resumeSeconds(type: .movie, tmdbId: String(id), season: nil, episode: nil)
        guard let url = StreamingProviderURLBuilder.movieURL(tmdbId: id, progressSeconds: resume) else {
            return nil
        }

        return WatchItem(type: .movie, title: title, tmdbId: String(id), posterPath: posterPath, generatedURL: url)
    }

    func episodeItem(
        seriesId: Int,
        seriesName: String,
        posterPath: String?,
        season: Int,
        episode: Int,
        episodeName: String?
    ) -> WatchItem? {
        let resume = continueWatching.resumeSeconds(type: .tv, tmdbId: String(seriesId), season: season, episode: episode)
        guard let url = StreamingProviderURLBuilder.tvURL(
            tmdbId: seriesId,
            season: season,
            episode: episode,
            progressSeconds: resume
        ) else {
            return nil
        }

        return WatchItem(
            type: .tv,
            title: seriesName,
            tmdbId: String(seriesId),
            season: season,
            episode: episode,
            episodeName: episodeName,
            posterPath: posterPath,
            generatedURL: url
        )
    }

    /// Adds the item to history and moves it to the front of Continue Watching, keeping
    /// any saved position when it's the same movie/episode.
    func record(_ item: WatchItem) {
        history.add(item)

        let existing = continueWatching.items.first { $0.type == item.type && $0.tmdbId == item.tmdbId }
        let sameEpisode = existing?.season == item.season && existing?.episode == item.episode

        continueWatching.addOrUpdate(
            item: ContinueWatchingItem(
                type: item.type,
                title: item.title,
                tmdbId: item.tmdbId,
                season: item.season,
                episode: item.episode,
                episodeName: item.episodeName ?? (sameEpisode ? existing?.episodeName : nil),
                posterPath: item.posterPath ?? existing?.posterPath,
                playableURL: item.generatedURL,
                progressSeconds: sameEpisode ? existing?.progressSeconds : nil,
                durationSeconds: sameEpisode ? existing?.durationSeconds : nil
            )
        )
    }
}

/// Resume details for one title, derived from its Continue Watching entry.
struct NFResumeState: Equatable {
    let season: Int?
    let episode: Int?
    let episodeName: String?
    let fraction: Double?
    let remainingSeconds: Double?

    init(entry: ContinueWatchingItem) {
        season = entry.season
        episode = entry.episode
        episodeName = entry.episodeName
        fraction = entry.progressFraction

        if let progress = entry.progressSeconds, let duration = entry.durationSeconds, duration > 0 {
            remainingSeconds = max(duration - progress, 0)
        } else {
            remainingSeconds = nil
        }
    }

    /// e.g. "S2:E4" for series, nil for films.
    var episodeLabel: String? {
        guard let season, let episode else { return nil }
        return "S\(season):E\(episode)"
    }

    var hasProgress: Bool {
        (fraction ?? 0) > 0.01
    }

    var detailLine: String? {
        let remaining = remainingSeconds.map { NF.remainingText(seconds: $0) }
        switch (episodeLabel, remaining) {
        case let (label?, remaining?): return "\(label) · \(remaining)"
        case let (label?, nil): return label
        case let (nil, remaining?): return remaining
        default: return nil
        }
    }
}

// MARK: - Picker overlay request

struct NFPickerOption: Identifiable, Hashable {
    let id: String
    let title: String
}

struct NFPickerRequest: Identifiable {
    let id = UUID()
    let options: [NFPickerOption]
    let selectedID: String?
    let onSelect: (String) -> Void
}
