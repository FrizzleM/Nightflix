import SwiftUI

struct SeriesDetailView: View {
    let seriesId: Int
    let fallbackName: String
    let fallbackPosterPath: String?
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager

    @State private var viewModel = SeasonEpisodeViewModel()
    @State private var selectedItem: WatchItem?
    @State private var playErrorMessage: String?
    @State private var entranceVisible = false

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header
                    seasonsSection
                    episodesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(seriesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedItem) { item in
            PlayerView(item: item, continueWatchingManager: continueWatchingManager)
        }
        .onAppear {
            startEntrance()
        }
        .task {
            await viewModel.loadSeriesIfNeeded(seriesId: seriesId)
        }
        .tint(NightFlixStyle.accentColor)
        .onChange(of: viewModel.seriesErrorMessage) { _, newValue in
            if newValue != nil {
                HapticManager.shared.error()
            }
        }
        .onChange(of: viewModel.seasonErrorMessage) { _, newValue in
            if newValue != nil {
                HapticManager.shared.error()
            }
        }
    }

    private var seriesTitle: String {
        viewModel.seriesDetails?.name ?? fallbackName
    }

    private var posterPath: String? {
        viewModel.seriesDetails?.posterPath ?? fallbackPosterPath
    }

    private var posterURL: URL? {
        guard let posterPath else { return nil }
        return TMDBConfig.imageBaseURL.appending(path: posterPath)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            NightFlixPosterImage(url: posterURL, width: 116, height: 174)
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.1, yOffset: 14)

            VStack(alignment: .leading, spacing: 10) {
                Text(seriesTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(3)
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.18, yOffset: 12, scaleAmount: 0.98)

                if let year = viewModel.seriesDetails?.firstAirYear, !year.isEmpty {
                    Text(year)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.58))
                        .nightflixEntrance(isVisible: entranceVisible, delay: 0.24, yOffset: 10, scaleAmount: 0.98)
                }

                if let overview = viewModel.seriesDetails?.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.7))
                        .lineLimit(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .nightflixEntrance(isVisible: entranceVisible, delay: 0.3, yOffset: 10, scaleAmount: 0.98)
                } else if viewModel.isLoadingSeries {
                    VStack(alignment: .leading, spacing: 8) {
                        TextLineSkeletonView(width: nil, height: 11)
                        TextLineSkeletonView(width: nil, height: 11)
                        TextLineSkeletonView(width: 150, height: 11)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightFlixResultCardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var seasonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Seasons", isLoading: viewModel.isLoadingSeries)

            if let errorMessage = viewModel.seriesErrorMessage {
                messageRow(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.42, yOffset: 12)
            } else if viewModel.isLoadingSeries && viewModel.seasons.isEmpty {
                SeasonSkeletonRowView()
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.42, yOffset: 12, scaleAmount: 0.98)
            } else if viewModel.seasons.isEmpty {
                messageRow("No seasons are available for this series.", systemImage: "tray.fill")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.42, yOffset: 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(Array(viewModel.seasons.enumerated()), id: \.element.id) { index, season in
                            seasonCard(season)
                                .nightflixEntrance(isVisible: entranceVisible, delay: cardDelay(index, baseDelay: 0.42), yOffset: 12)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Episodes", isLoading: viewModel.isLoadingSeason)

            if let playErrorMessage {
                messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.5, yOffset: 12)
            }

            if let errorMessage = viewModel.seasonErrorMessage {
                messageRow(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.5, yOffset: 12)
            } else if viewModel.selectedSeason == nil {
                messageRow("Choose a season to view episodes.", systemImage: "list.bullet.rectangle")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.5, yOffset: 12)
            } else if viewModel.isLoadingSeason {
                EpisodeSkeletonListView(count: 3)
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.5, yOffset: 12, scaleAmount: 0.98)
            } else if viewModel.episodes.isEmpty {
                messageRow("No episodes are available for this season.", systemImage: "tray.fill")
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.5, yOffset: 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.episodes.enumerated()), id: \.element.id) { index, episode in
                        if index > 0 {
                            Divider().overlay(NightFlixStyle.borderColor)
                        }
                        episodeRow(episode)
                            .nightflixEntrance(isVisible: entranceVisible, delay: cardDelay(index, baseDelay: 0.5), yOffset: 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String, isLoading: Bool) -> some View {
        SectionHeaderView(title: title)
        .nightflixEntrance(isVisible: entranceVisible, delay: title == "Seasons" ? 0.36 : 0.46, yOffset: 12, scaleAmount: 0.98)
    }

    private func seasonCard(_ season: Season) -> some View {
        let isSelected = viewModel.selectedSeason?.id == season.id

        return Button {
            playErrorMessage = nil
            HapticManager.shared.selection()
            Task {
                await viewModel.selectSeason(season, seriesId: seriesId)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                NightFlixPosterImage(url: season.posterURL, width: 128, height: 192)

                Text(season.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)

                Text("Season \(season.seasonNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.64))

                Text("\(season.episodeCount) episodes")
                    .font(.caption)
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.58))

                if let airDate = season.airDate, !airDate.isEmpty {
                    Text(airDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.48, light: .tertiaryLabel))
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: 190, alignment: .topLeading)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? NightFlixStyle.accentColor : NightFlixStyle.borderColor, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func episodeRow(_ episode: Episode) -> some View {
        Button {
            HapticManager.shared.mediumImpact()
            play(episode)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 13) {
                    ZStack {
                        NightflixPoster(url: episode.stillURL, width: 132, height: 76, cornerRadius: 6)

                        Circle()
                            .fill(.black.opacity(0.4))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            .overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(episode.episodeNumber). \(episode.name)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(NightFlixStyle.primaryTextColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        if let airDate = episode.airDate, !airDate.isEmpty {
                            Text(airDate)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(NightFlixStyle.secondaryTextColor)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if !episode.overview.isEmpty {
                    Text(episode.overview)
                        .font(.footnote)
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.62))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play episode \(episode.episodeNumber), \(episode.name)")
    }

    private func messageRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NightFlixStyle.subtleFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func play(_ episode: Episode) {
        playErrorMessage = nil

        guard let url = StreamingProviderURLBuilder.tvURL(
            tmdbId: seriesId,
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            progressSeconds: continueWatchingManager.resumeSeconds(
                type: .tv,
                tmdbId: String(seriesId),
                season: episode.seasonNumber,
                episode: episode.episodeNumber
            )
        ) else {
            playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
            HapticManager.shared.error()
            return
        }

        let item = WatchItem(
            type: .tv,
            title: seriesTitle,
            tmdbId: String(seriesId),
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            episodeName: episode.name,
            posterPath: posterPath,
            generatedURL: url
        )
        historyManager.add(item)
        continueWatchingManager.addOrUpdate(
            item: ContinueWatchingItem(
                type: .tv,
                title: seriesTitle,
                tmdbId: String(seriesId),
                season: episode.seasonNumber,
                episode: episode.episodeNumber,
                episodeName: episode.name,
                posterPath: posterPath,
                playableURL: url
            )
        )
        selectedItem = item
    }

    private func startEntrance() {
        guard !entranceVisible else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            entranceVisible = true
        }
    }

    private func cardDelay(_ index: Int, baseDelay: Double) -> Double {
        baseDelay + min(Double(index) * 0.055, 0.44)
    }
}

#Preview {
    NavigationStack {
        SeriesDetailView(
            seriesId: 1399,
            fallbackName: "Game of Thrones",
            fallbackPosterPath: nil,
            historyManager: WatchHistoryManager(),
            continueWatchingManager: ContinueWatchingManager()
        )
    }
}
