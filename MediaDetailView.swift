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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $selectedPlayerItem) { item in
            PlayerView(item: item, continueWatchingManager: continueWatchingManager)
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
                LazyVStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: 22) {
                        if let playErrorMessage {
                            messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
                        }

                        primaryActions

                        if let movie = viewModel.movieDetail {
                            movieContent(movie)
                        } else if let tv = viewModel.tvDetail {
                            tvContent(tv)
                        }
                    }
                    .padding(.horizontal, 20)
                    .nightflixEntrance(isVisible: entranceVisible, delay: 0.16, yOffset: 16, scaleAmount: 0.99, animationsEnabled: animationsEnabled)
                }
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Header

    private var header: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width

                    ZStack(alignment: .bottom) {
                        DetailBackdropImage(url: backdropURL ?? posterURL)
                            .frame(width: width, height: 420)
                            .clipped()

                        LinearGradient(
                            colors: [.black.opacity(0.55), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )

                        LinearGradient(
                            colors: [
                                .clear,
                                NightFlixStyle.backgroundColor.opacity(0.45),
                                NightFlixStyle.backgroundColor.opacity(0.9),
                                NightFlixStyle.backgroundColor
                            ],
                            startPoint: .center,
                            endPoint: .bottom
                        )

                        VStack(spacing: 10) {
                            Text(currentTitle)
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.7)
                                .shadow(color: .black.opacity(0.55), radius: 8, y: 3)

                            if !currentMetadata.isEmpty {
                                Text(currentMetadata.joined(separator: "   •   "))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.82))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
                            }
                        }
                        .frame(width: max(width - 48, 0))
                        .padding(.bottom, 6)
                    }
                    .frame(width: width, height: 420)
                }
            }
    }

    // MARK: - Primary actions

    @ViewBuilder
    private var primaryActions: some View {
        VStack(spacing: 16) {
            primaryPlayButton

            HStack(alignment: .top, spacing: 0) {
                myListAction

                if let trailerURL = currentTrailerURL {
                    iconAction(systemImage: "play.rectangle.fill", label: "Trailer") {
                        HapticManager.shared.lightImpact()
                        openURL(trailerURL)
                    }
                }

                shareAction
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var primaryPlayButton: some View {
        if let movie = viewModel.movieDetail {
            bigPlayButton(title: "Play") { playMovie(movie) }
        } else if let tv = viewModel.tvDetail, let episode = viewModel.selectedSeasonDetail?.episodes.first {
            bigPlayButton(title: "Play  •  S\(episode.seasonNumber) E\(episode.episodeNumber)") {
                playEpisode(episode, tv: tv)
            }
        }
    }

    private func bigPlayButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(NightflixPressableStyle(pressedScale: 0.97))
        .accessibilityLabel("Play \(currentTitle)")
    }

    private var myListAction: some View {
        let saved = isInMyList

        return iconAction(
            systemImage: saved ? "checkmark" : "plus",
            label: "My List",
            tint: saved ? NightFlixStyle.accentColor : .white
        ) {
            if saved {
                HapticManager.shared.toggleOff()
            } else {
                HapticManager.shared.bloom()
            }
            toggleMyList()
        }
    }

    @ViewBuilder
    private var shareAction: some View {
        if let url = tmdbWebURL {
            ShareLink(item: url) {
                iconActionLabel(systemImage: "square.and.arrow.up", label: "Share", tint: .white)
            }
            .buttonStyle(NightflixPressableStyle(pressedScale: 0.9))
            .frame(maxWidth: .infinity)
        }
    }

    private func iconAction(
        systemImage: String,
        label: String,
        tint: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            iconActionLabel(systemImage: systemImage, label: label, tint: tint)
        }
        .buttonStyle(NightflixPressableStyle(pressedScale: 0.9))
        .frame(maxWidth: .infinity)
    }

    private func iconActionLabel(systemImage: String, label: String, tint: Color) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .frame(height: 24)

            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Movie content

    private func movieContent(_ movie: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            overviewSection(overview: movie.overview, tagline: movie.tagline)
            metadataTextLines(genres: movie.genres, people: [("Director", directors(from: movie.credits?.crew ?? []))])
            castSection(movie.credits?.cast ?? [])
            recommendationsSection(
                title: "More Like This",
                items: mergedRecommendations(movie.recommendations?.results ?? [], movie.similar?.results ?? []),
                mediaType: "movie"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - TV content

    private func tvContent(_ tv: TVSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            overviewSection(overview: tv.overview, tagline: tv.tagline)
            metadataTextLines(genres: tv.genres, people: [("Created By", tv.createdBy.map(\.name))])
            episodesSection(tv)
            castSection(tv.credits?.cast ?? [])
            recommendationsSection(
                title: "More Like This",
                items: mergedRecommendations(tv.recommendations?.results ?? [], tv.similar?.results ?? []),
                mediaType: "tv"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Overview & metadata text

    private func overviewSection(overview: String, tagline: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(.subheadline.weight(.semibold))
                    .italic()
                    .foregroundStyle(NightFlixStyle.accentColor)
            }

            Text(overview.isEmpty ? "No overview is available for this title." : overview)
                .font(.subheadline)
                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.82))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func metadataTextLines(genres: [Genre], people: [(String, [String])]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !genres.isEmpty {
                metadataTextLine(label: "Genres", value: genres.map(\.name).joined(separator: ", "))
            }

            ForEach(Array(people.enumerated()), id: \.offset) { _, entry in
                let names = entry.1.filter { !$0.isEmpty }
                if !names.isEmpty {
                    metadataTextLine(label: entry.0, value: names.joined(separator: ", "))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataTextLine(label: String, value: String) -> some View {
        (
            Text("\(label):  ")
                .foregroundStyle(NightFlixStyle.tertiaryTextColor)
            + Text(value)
                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.7))
        )
        .font(.footnote.weight(.medium))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cast

    @ViewBuilder
    private func castSection(_ cast: [CastMember]) -> some View {
        let visibleCast = Array(cast.sorted { ($0.order ?? 999) < ($1.order ?? 999) }.prefix(12))

        if !visibleCast.isEmpty {
            VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
                SectionHeaderView(title: "Cast")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(visibleCast) { member in
                            VStack(spacing: 7) {
                                NightflixPoster(url: member.profileURL, width: 76, height: 76, cornerRadius: 38)

                                Text(member.name)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                                    .lineLimit(1)

                                if let character = member.character, !character.isEmpty {
                                    Text(character)
                                        .font(.caption2)
                                        .foregroundStyle(NightFlixStyle.secondaryTextColor)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 84)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Episodes

    private func episodesSection(_ tv: TVSeriesDetail) -> some View {
        VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("Episodes")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 12)

                seasonMenu(tv)
            }

            episodesBody(tv)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func seasonMenu(_ tv: TVSeriesDetail) -> some View {
        let seasons = tv.seasons.filter { $0.seasonNumber > 0 }

        if seasons.count > 1 {
            Menu {
                ForEach(seasons) { season in
                    Button {
                        HapticManager.shared.selection()
                        playErrorMessage = nil
                        Task {
                            await viewModel.selectSeason(seriesId: tv.id, seasonNumber: season.seasonNumber)
                        }
                    } label: {
                        Text(season.name)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(currentSeasonTitle(tv))
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.black))
                }
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(NightFlixStyle.fillColor(darkOpacity: 0.1), in: Capsule())
                .overlay { Capsule().stroke(NightFlixStyle.borderColor, lineWidth: 1) }
            }
        }
    }

    @ViewBuilder
    private func episodesBody(_ tv: TVSeriesDetail) -> some View {
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
                VStack(spacing: 0) {
                    ForEach(Array(seasonDetail.episodes.enumerated()), id: \.element.id) { index, episode in
                        if index > 0 {
                            Divider().overlay(NightFlixStyle.borderColor)
                        }
                        episodeRow(episode, tv: tv)
                    }
                }
            }
        }
    }

    private func episodeRow(_ episode: EpisodeDetail, tv: TVSeriesDetail) -> some View {
        Button {
            playEpisode(episode, tv: tv)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 13) {
                    ZStack {
                        NightflixPoster(url: episode.stillURL, width: 132, height: 76, cornerRadius: 6, aspectRatio: 16.0 / 9.0)

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

                        if let runtime = runtimeText(episode.runtime) {
                            Text(runtime)
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
        .accessibilityLabel("Play \(tv.name), season \(episode.seasonNumber), episode \(episode.episodeNumber)")
    }

    // MARK: - More like this

    @ViewBuilder
    private func recommendationsSection(title: String, items: [MediaRecommendationItem], mediaType: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
                SectionHeaderView(title: title)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: NightflixLayout.rowItemSpacing) {
                        ForEach(items.prefix(14)) { item in
                            PosterCard(
                                url: item.posterURL,
                                width: 110,
                                accessibilityLabel: item.displayTitle,
                                action: { openRecommendation(item, mediaType: item.mediaType ?? mediaType) }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - States

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

    // MARK: - Derived values

    private var currentTitle: String {
        viewModel.movieDetail?.title ?? viewModel.tvDetail?.name ?? fallbackTitle
    }

    private var currentMetadata: [String] {
        if let movie = viewModel.movieDetail {
            return [
                "Movie",
                movie.releaseYear,
                runtimeText(movie.runtime),
                ratingText(movie.voteAverage, voteCount: movie.voteCount)
            ].compactMap { $0 }
        }

        if let tv = viewModel.tvDetail {
            let yearRange = [tv.firstAirYear, tv.lastAirYear].compactMap { $0 }.joined(separator: "-")
            return [
                "Series",
                yearRange.isEmpty ? nil : yearRange,
                "\(tv.numberOfSeasons) Season\(tv.numberOfSeasons == 1 ? "" : "s")",
                ratingText(tv.voteAverage, voteCount: tv.voteCount)
            ].compactMap { $0 }
        }

        return [mediaType == "movie" ? "Movie" : "TV Series"]
    }

    private var currentTrailerURL: URL? {
        let videos = viewModel.movieDetail?.videos?.results ?? viewModel.tvDetail?.videos?.results ?? []
        return preferredTrailerURL(from: videos)
    }

    private var isInMyList: Bool {
        guard let type = MediaType(tmdbValue: currentMediaType) else { return false }
        return myListManager.contains(mediaType: type, tmdbId: id)
    }

    private var currentMediaType: String {
        if viewModel.movieDetail != nil { return "movie" }
        if viewModel.tvDetail != nil { return "tv" }
        return mediaType
    }

    private var tmdbWebURL: URL? {
        URL(string: "https://www.themoviedb.org/\(currentMediaType)/\(id)")
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

    private func currentSeasonTitle(_ tv: TVSeriesDetail) -> String {
        guard let number = viewModel.selectedSeasonNumber else { return "Season" }
        if let season = tv.seasons.first(where: { $0.seasonNumber == number }) {
            return season.name
        }
        return "Season \(number)"
    }

    private func mergedRecommendations(
        _ primary: [MediaRecommendationItem],
        _ secondary: [MediaRecommendationItem]
    ) -> [MediaRecommendationItem] {
        var seen = Set<Int>()
        var merged: [MediaRecommendationItem] = []

        for item in primary + secondary where seen.insert(item.id).inserted {
            merged.append(item)
        }

        return merged
    }

    // MARK: - Actions

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

    private func toggleMyList() {
        let item: MyListItem?
        if let movie = viewModel.movieDetail {
            item = MyListItem(movie: movie)
        } else if let tv = viewModel.tvDetail {
            item = MyListItem(tv: tv)
        } else {
            item = nil
        }

        guard let item else { return }
        myListManager.toggle(item)
    }

    private func openRecommendation(_ item: MediaRecommendationItem, mediaType: String) {
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
    }

    private func playMovie(_ movie: MovieDetail) {
        playErrorMessage = nil
        HapticManager.shared.impactStrong()

        guard let url = StreamingProviderURLBuilder.movieURL(
            tmdbId: movie.id,
            progressSeconds: continueWatchingManager.resumeSeconds(
                type: .movie,
                tmdbId: String(movie.id),
                season: nil,
                episode: nil
            )
        ) else {
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
        HapticManager.shared.impactStrong()

        guard let url = StreamingProviderURLBuilder.tvURL(
            tmdbId: tv.id,
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            progressSeconds: continueWatchingManager.resumeSeconds(
                type: .tv,
                tmdbId: String(tv.id),
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
        return String(format: "★ %.1f", rating)
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
