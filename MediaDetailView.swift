import SwiftUI

struct MediaDetailView: View {
    let id: Int
    let mediaType: String
    let fallbackTitle: String
    let fallbackPosterPath: String?
    let fallbackBackdropPath: String?
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    @ObservedObject private var myListManager: MyListManager

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var viewModel = MediaDetailViewModel()
    @State private var selectedPlayerItem: WatchItem?
    @State private var selectedDetailItem: MediaItem?
    @State private var playErrorMessage: String?
    @State private var entranceVisible = false

    init(
        id: Int,
        mediaType: String,
        fallbackTitle: String,
        fallbackPosterPath: String? = nil,
        fallbackBackdropPath: String? = nil,
        historyManager: WatchHistoryManager,
        continueWatchingManager: ContinueWatchingManager,
        myListManager: MyListManager = MyListManager()
    ) {
        self.id = id
        self.mediaType = mediaType
        self.fallbackTitle = fallbackTitle
        self.fallbackPosterPath = fallbackPosterPath
        self.fallbackBackdropPath = fallbackBackdropPath
        self.historyManager = historyManager
        self.continueWatchingManager = continueWatchingManager
        _myListManager = ObservedObject(wrappedValue: myListManager)
    }

    init(
        item: MediaItem,
        historyManager: WatchHistoryManager,
        continueWatchingManager: ContinueWatchingManager,
        myListManager: MyListManager = MyListManager()
    ) {
        self.init(
            id: item.id,
            mediaType: item.mediaType,
            fallbackTitle: item.displayTitle,
            fallbackPosterPath: item.posterPath,
            fallbackBackdropPath: item.backdropPath,
            historyManager: historyManager,
            continueWatchingManager: continueWatchingManager,
            myListManager: myListManager
        )
    }

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            content
        }
        .navigationTitle(currentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPlayerItem) { item in
            PlayerView(item: item)
        }
            .navigationDestination(item: $selectedDetailItem) { item in
                MediaDetailView(
                    item: item,
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager,
                    myListManager: myListManager
                )
            }
        .task {
            await viewModel.loadIfNeeded(id: id, mediaType: mediaType)
        }
        .onAppear {
            startEntrance()
        }
        .tint(NightFlixStyle.accentColor)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.movieDetail == nil && viewModel.tvDetail == nil {
            loadingState
        } else if let errorMessage = viewModel.errorMessage, viewModel.movieDetail == nil && viewModel.tvDetail == nil {
            errorState(errorMessage)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 24) {
                    header

                    if let playErrorMessage {
                        messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
                    }

                    if let movie = viewModel.movieDetail {
                        movieContent(movie)
                    } else if let tv = viewModel.tvDetail {
                        tvContent(tv)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            DetailBackdropImage(url: backdropURL ?? posterURL)
                .frame(maxWidth: .infinity)
                .frame(height: 370)
                .clipped()

            LinearGradient(
                colors: [
                    .black.opacity(0.05),
                    .black.opacity(0.38),
                    .black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                NightFlixPosterImage(url: posterURL, width: 116, height: 174)
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 8)

                VStack(alignment: .leading, spacing: 9) {
                    Text(currentTitle)
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)

                    metadataLine
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 370)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 20, y: 12)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.05, yOffset: 14, scaleAmount: 0.98, animationsEnabled: animationsEnabled)
    }

    private var metadataLine: some View {
        FlexibleChipRow(
            chips: currentMetadata,
            foregroundColor: .white.opacity(0.9),
            backgroundColor: .white.opacity(0.15)
        )
    }

    private func movieContent(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Button {
                playMovie(movie)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(movie.title)")

            myListButton(MyListItem(movie: movie))
            overviewSection(overview: movie.overview, tagline: movie.tagline)
            genreSection(movie.genres)
            trailerButton(title: movie.title, url: preferredTrailerURL(from: movie.videos?.results ?? []))
            castSection(movie.credits?.cast ?? [])
            peopleSection(title: "Director", names: directors(from: movie.credits?.crew ?? []))
            recommendationSection(title: "Similar Titles", items: movie.similar?.results ?? [], mediaType: "movie")
            recommendationSection(title: "Recommended Titles", items: movie.recommendations?.results ?? [], mediaType: "movie")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.16, yOffset: 16, scaleAmount: 0.98, animationsEnabled: animationsEnabled)
    }

    private func tvContent(_ tv: TVSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            overviewSection(overview: tv.overview, tagline: tv.tagline)
            genreSection(tv.genres)
            trailerButton(title: tv.name, url: preferredTrailerURL(from: tv.videos?.results ?? []))
            myListButton(MyListItem(tv: tv))
            seasonsSection(tv)
            episodesSection(tv)
            castSection(tv.credits?.cast ?? [])
            peopleSection(title: "Created By", names: tv.createdBy.map(\.name))
            recommendationSection(title: "Similar Series", items: tv.similar?.results ?? [], mediaType: "tv")
            recommendationSection(title: "Recommended Series", items: tv.recommendations?.results ?? [], mediaType: "tv")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.16, yOffset: 16, scaleAmount: 0.98, animationsEnabled: animationsEnabled)
    }

    private func overviewSection(overview: String, tagline: String?) -> some View {
        DetailSection(title: "Overview") {
            VStack(alignment: .leading, spacing: 10) {
                if let tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.headline.weight(.semibold))
                        .italic()
                        .foregroundStyle(NightFlixStyle.accentColor)
                }

                Text(overview.isEmpty ? "No overview is available for this title." : overview)
                    .font(.body)
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.76))
                    .lineSpacing(3)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func genreSection(_ genres: [Genre]) -> some View {
        if !genres.isEmpty {
            DetailSection(title: "Genres") {
                FlexibleChipRow(
                    chips: genres.map(\.name),
                    foregroundColor: NightFlixStyle.primaryTextColor,
                    backgroundColor: NightFlixStyle.fillColor(darkOpacity: 0.08)
                )
            }
        }
    }

    @ViewBuilder
    private func trailerButton(title: String, url: URL?) -> some View {
        if let url {
            Button {
                openURL(url)
            } label: {
                Label("Trailer", systemImage: "play.rectangle.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(NightFlixStyle.borderColor, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open trailer for \(title)")
        }
    }

    private func myListButton(_ item: MyListItem) -> some View {
        let isSaved = myListManager.contains(mediaType: item.mediaType, tmdbId: item.tmdbId)

        return Button {
            HapticManager.shared.lightImpact()
            myListManager.toggle(item)
        } label: {
            Label(isSaved ? "In Watch Later" : "Add to Watch Later", systemImage: "clock.fill")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(isSaved ? NightFlixStyle.primaryTextColor : .white)
                .background(
                    isSaved ? NightFlixStyle.cardColor : NightFlixStyle.accentColor,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSaved ? NightFlixStyle.accentColor.opacity(0.85) : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove \(item.title) from Watch Later" : "Add \(item.title) to Watch Later")
    }

    @ViewBuilder
    private func castSection(_ cast: [CastMember]) -> some View {
        let visibleCast = Array(cast.sorted { ($0.order ?? 999) < ($1.order ?? 999) }.prefix(12))

        if !visibleCast.isEmpty {
            DetailSection(title: "Cast") {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(visibleCast) { member in
                            VStack(alignment: .leading, spacing: 8) {
                                NightFlixPosterImage(url: member.profileURL, width: 112, height: 168)

                                Text(member.name)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(width: 112, alignment: .topLeading)

                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.caption2)
                                        .foregroundStyle(NightFlixStyle.secondaryTextColor)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(width: 112, alignment: .topLeading)
                                }
                            }
                            .frame(width: 112, alignment: .topLeading)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func peopleSection(title: String, names: [String]) -> some View {
        let visibleNames = names.filter { !$0.isEmpty }

        if !visibleNames.isEmpty {
            DetailSection(title: title) {
                Text(visibleNames.joined(separator: ", "))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func seasonsSection(_ tv: TVSeriesDetail) -> some View {
        DetailSection(title: "Seasons") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(tv.seasons.filter { $0.seasonNumber > 0 }) { season in
                        seasonCard(season, seriesId: tv.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func seasonCard(_ season: Season, seriesId: Int) -> some View {
        let isSelected = viewModel.selectedSeasonNumber == season.seasonNumber

        return Button {
            HapticManager.shared.selection()
            playErrorMessage = nil
            Task {
                await viewModel.selectSeason(seriesId: seriesId, seasonNumber: season.seasonNumber)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                NightFlixPosterImage(url: season.posterURL, width: 126, height: 189)

                Text(season.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)

                Text("Season \(season.seasonNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightFlixStyle.secondaryTextColor)

                Text("\(season.episodeCount) episodes")
                    .font(.caption)
                    .foregroundStyle(NightFlixStyle.secondaryTextColor)

                if let airDate = season.airDate, !airDate.isEmpty {
                    Text(airDate)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.tertiaryTextColor)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(width: 190, alignment: .topLeading)
            .contentShape(Rectangle())
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? NightFlixStyle.accentColor : NightFlixStyle.borderColor, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func episodesSection(_ tv: TVSeriesDetail) -> some View {
        DetailSection(title: "Episodes") {
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.selectedSeasonNumber == nil {
                    messageRow("Choose a season to view episodes.", systemImage: "list.bullet.rectangle")
                } else if viewModel.isLoadingSeason {
                    EpisodeSkeletonListView(count: 3)
                } else if let errorMessage = viewModel.seasonErrorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        messageRow(errorMessage, systemImage: "exclamationmark.circle.fill")
                        retrySeasonButton(seriesId: tv.id)
                    }
                } else if let seasonDetail = viewModel.selectedSeasonDetail {
                    if seasonDetail.episodes.isEmpty {
                        messageRow("No episodes are available for this season.", systemImage: "tray.fill")
                    } else {
                        ForEach(seasonDetail.episodes) { episode in
                            episodeCard(episode, tv: tv)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func episodeCard(_ episode: EpisodeDetail, tv: TVSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    episodeImage(episode)
                    episodeInfo(episode)
                }

                VStack(alignment: .leading, spacing: 14) {
                    episodeImage(episode)
                    episodeInfo(episode)
                }
            }

            if !episode.overview.isEmpty {
                Text(episode.overview)
                    .font(.subheadline)
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.68))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                playEpisode(episode, tv: tv)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(tv.name), season \(episode.seasonNumber), episode \(episode.episodeNumber)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightFlixResultCardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func episodeImage(_ episode: EpisodeDetail) -> some View {
        NightFlixPosterImage(url: episode.stillURL, width: 124, height: 70)
    }

    private func episodeInfo(_ episode: EpisodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Episode \(episode.episodeNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(NightFlixStyle.accentColor)

            Text(episode.name)
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            FlexibleChipRow(
                chips: episodeMetadata(for: episode),
                foregroundColor: NightFlixStyle.secondaryTextColor,
                backgroundColor: NightFlixStyle.fillColor(darkOpacity: 0.07)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func recommendationSection(title: String, items: [MediaRecommendationItem], mediaType: String) -> some View {
        if !items.isEmpty {
            DetailSection(title: title) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items.prefix(14)) { item in
                            recommendationCard(item, mediaType: item.mediaType ?? mediaType)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func recommendationCard(_ item: MediaRecommendationItem, mediaType: String) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            selectedDetailItem = MediaItem(
                id: item.id,
                mediaType: mediaType,
                title: mediaType == "movie" ? item.displayTitle : nil,
                name: mediaType == "tv" ? item.displayTitle : nil,
                overview: item.overview ?? "",
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                NightFlixPosterImage(url: item.posterURL, width: 126, height: 189)

                Text(item.displayTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)

                if let year = item.displayYear {
                    Text(year)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.secondaryTextColor)
                }

                Label("Play", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(10)
            .frame(width: 148, alignment: .topLeading)
            .contentShape(Rectangle())
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NightFlixStyle.borderColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(item.displayTitle)")
    }

    private var loadingState: some View {
        DetailPageSkeletonView()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(NightFlixStyle.accentColor)

            Text("Details could not be loaded.")
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(NightFlixStyle.secondaryTextColor)
                .lineLimit(3)

            Button {
                Task {
                    await viewModel.reload(id: id, mediaType: mediaType)
                }
            } label: {
                Text("Retry")
                    .font(.headline.weight(.bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white)
                    .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retrySeasonButton(seriesId: Int) -> some View {
        Button {
            guard let seasonNumber = viewModel.selectedSeasonNumber else { return }
            Task {
                await viewModel.selectSeason(seriesId: seriesId, seasonNumber: seasonNumber, forceReload: true)
            }
        } label: {
            Text("Retry")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func messageRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NightFlixStyle.subtleFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var currentTitle: String {
        viewModel.movieDetail?.title ?? viewModel.tvDetail?.name ?? fallbackTitle
    }

    private var currentMetadata: [String] {
        if let movie = viewModel.movieDetail {
            return [
                movie.releaseYear,
                runtimeText(movie.runtime),
                ratingText(movie.voteAverage, voteCount: movie.voteCount)
            ].compactMap { $0 }
        }

        if let tv = viewModel.tvDetail {
            let yearRange = [tv.firstAirYear, tv.lastAirYear].compactMap { $0 }.joined(separator: "-")
            return [
                yearRange.isEmpty ? nil : yearRange,
                "\(tv.numberOfSeasons) seasons",
                "\(tv.numberOfEpisodes) episodes",
                tv.status,
                ratingText(tv.voteAverage, voteCount: tv.voteCount)
            ].compactMap { $0 }
        }

        return [mediaType == "movie" ? "Movie" : "TV Series"]
    }

    private var posterURL: URL? {
        let path = viewModel.movieDetail?.posterPath ?? viewModel.tvDetail?.posterPath ?? fallbackPosterPath
        guard let path else { return nil }
        return TMDBConfig.posterImageBaseURL.appending(path: path)
    }

    private var backdropURL: URL? {
        let path = viewModel.movieDetail?.backdropPath ?? viewModel.tvDetail?.backdropPath ?? fallbackBackdropPath
        guard let path else { return nil }
        return TMDBConfig.backdropImageBaseURL.appending(path: path)
    }

    private var animationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private func startEntrance() {
        guard !entranceVisible else { return }

        guard animationsEnabled else {
            entranceVisible = true
            return
        }

        withAnimation(.easeOut(duration: 0.35)) {
            entranceVisible = true
        }
    }

    private func playMovie(_ movie: MovieDetail) {
        playErrorMessage = nil
        HapticManager.shared.mediumImpact()

        guard let url = StreamingProviderURLBuilder.movieURL(tmdbId: movie.id) else {
            playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
            HapticManager.shared.error()
            return
        }

        let item = WatchItem(
            type: .movie,
            title: movie.title,
            tmdbId: String(movie.id),
            posterPath: movie.posterPath,
            generatedURL: url
        )
        historyManager.add(item)
        continueWatchingManager.addOrUpdate(
            item: ContinueWatchingItem(
                type: .movie,
                title: movie.title,
                tmdbId: String(movie.id),
                posterPath: movie.posterPath,
                playableURL: url
            )
        )
        selectedPlayerItem = item
    }

    private func playEpisode(_ episode: EpisodeDetail, tv: TVSeriesDetail) {
        playErrorMessage = nil
        HapticManager.shared.mediumImpact()

        guard let url = StreamingProviderURLBuilder.tvURL(
            tmdbId: tv.id,
            season: episode.seasonNumber,
            episode: episode.episodeNumber
        ) else {
            playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
            HapticManager.shared.error()
            return
        }

        let item = WatchItem(
            type: .tv,
            title: tv.name,
            tmdbId: String(tv.id),
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            episodeName: episode.name,
            posterPath: tv.posterPath,
            generatedURL: url
        )
        historyManager.add(item)
        continueWatchingManager.addOrUpdate(
            item: ContinueWatchingItem(
                type: .tv,
                title: tv.name,
                tmdbId: String(tv.id),
                season: episode.seasonNumber,
                episode: episode.episodeNumber,
                episodeName: episode.name,
                posterPath: tv.posterPath,
                playableURL: url
            )
        )
        selectedPlayerItem = item
    }

    private func preferredTrailerURL(from videos: [VideoResult]) -> URL? {
        let youtubeTrailers = videos.filter {
            $0.site.caseInsensitiveCompare("YouTube") == .orderedSame &&
            $0.type.caseInsensitiveCompare("Trailer") == .orderedSame
        }

        return youtubeTrailers.first { $0.official == true }?.youtubeURL ?? youtubeTrailers.first?.youtubeURL
    }

    private func directors(from crew: [CrewMember]) -> [String] {
        crew.filter { $0.job == "Director" }.map(\.name)
    }

    private func runtimeText(_ runtime: Int?) -> String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    private func ratingText(_ rating: Double, voteCount: Int) -> String? {
        guard rating > 0 else { return nil }
        return String(format: "%.1f TMDB", rating)
    }

    private func episodeMetadata(for episode: EpisodeDetail) -> [String] {
        [
            episode.airDate,
            runtimeText(episode.runtime)
        ].compactMap { $0 }.filter { !$0.isEmpty }
    }
}

@Observable
@MainActor
final class MediaDetailViewModel {
    var movieDetail: MovieDetail?
    var tvDetail: TVSeriesDetail?
    var selectedSeasonDetail: SeasonDetail?
    var selectedSeasonNumber: Int?
    var isLoading = false
    var isLoadingSeason = false
    var errorMessage: String?
    var seasonErrorMessage: String?

    private let service: TMDBService
    private var loadedKey: String?
    private var seasonCache: [Int: SeasonDetail] = [:]
    private var detailRequestID: UUID?
    private var seasonRequestID: UUID?

    init() {
        self.service = TMDBService()
    }

    func loadIfNeeded(id: Int, mediaType: String) async {
        let key = "\(mediaType)-\(id)"
        guard loadedKey != key else { return }
        await reload(id: id, mediaType: mediaType)
    }

    func reload(id: Int, mediaType: String) async {
        let requestID = UUID()
        detailRequestID = requestID
        seasonRequestID = nil
        loadedKey = "\(mediaType)-\(id)"
        isLoading = true
        isLoadingSeason = false
        errorMessage = nil
        seasonErrorMessage = nil
        movieDetail = nil
        tvDetail = nil
        selectedSeasonDetail = nil
        selectedSeasonNumber = nil
        seasonCache = [:]

        do {
            if mediaType == "movie" {
                let detail = try await service.fetchMovieDetail(movieId: id)
                guard detailRequestID == requestID else { return }

                movieDetail = detail
            } else {
                let detail = try await service.fetchTVSeriesDetail(seriesId: id)
                guard detailRequestID == requestID else { return }

                tvDetail = detail

                if let firstSeason = detail.seasons.first(where: { $0.seasonNumber > 0 }) {
                    await selectSeason(seriesId: id, seasonNumber: firstSeason.seasonNumber)
                }
            }
        } catch is CancellationError {
            guard detailRequestID == requestID else { return }
        } catch {
            guard detailRequestID == requestID else { return }

            errorMessage = "Please check your connection and try again."
        }

        guard detailRequestID == requestID else { return }

        isLoading = false
        detailRequestID = nil
    }

    func selectSeason(seriesId: Int, seasonNumber: Int, forceReload: Bool = false) async {
        let requestID = UUID()
        seasonRequestID = requestID
        selectedSeasonNumber = seasonNumber
        seasonErrorMessage = nil

        if !forceReload, let cachedSeason = seasonCache[seasonNumber] {
            selectedSeasonDetail = cachedSeason
            isLoadingSeason = false
            seasonRequestID = nil
            return
        }

        isLoadingSeason = true
        selectedSeasonDetail = nil

        do {
            let season = try await service.fetchSeasonDetail(seriesId: seriesId, seasonNumber: seasonNumber)
            guard seasonRequestID == requestID else { return }

            seasonCache[seasonNumber] = season
            selectedSeasonDetail = season
        } catch is CancellationError {
            guard seasonRequestID == requestID else { return }
        } catch {
            guard seasonRequestID == requestID else { return }

            seasonErrorMessage = "Episodes could not be loaded. Please try again."
        }

        guard seasonRequestID == requestID else { return }

        isLoadingSeason = false
        seasonRequestID = nil
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FlexibleChipRow: View {
    let chips: [String]
    let foregroundColor: Color
    let backgroundColor: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 7) {
                chipViews
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var chipViews: some View {
        ForEach(chips.filter { !$0.isEmpty }, id: \.self) { chip in
            Text(chip)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(backgroundColor, in: Capsule())
        }
    }
}

private struct DetailBackdropImage: View {
    let url: URL?

    var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    SkeletonView(cornerRadius: 0)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [
                NightFlixStyle.fillColor(darkOpacity: 0.14),
                NightFlixStyle.fillColor(darkOpacity: 0.05),
                .black.opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension FeedItem {
    var mediaItem: MediaItem {
        MediaItem(
            id: id,
            mediaType: type == .movie ? "movie" : "tv",
            title: type == .movie ? title : nil,
            name: type == .tv ? title : nil,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath
        )
    }
}

extension MediaSearchResult {
    var mediaItem: MediaItem {
        MediaItem(
            id: id,
            mediaType: mediaType,
            title: title,
            name: name,
            overview: overview,
            releaseDate: releaseDate,
            firstAirDate: firstAirDate,
            posterPath: posterPath,
            backdropPath: backdropPath
        )
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(
            id: 550,
            mediaType: "movie",
            fallbackTitle: "Fight Club",
            historyManager: WatchHistoryManager(),
            continueWatchingManager: ContinueWatchingManager()
        )
        .environmentObject(AppSettingsManager())
    }
}
