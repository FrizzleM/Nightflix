import Observation
import SwiftUI

/// Full-screen title page container. "More Like This" pushes further title pages onto
/// the same stack (swipe back to return); the close button dismisses the whole stack.
struct NFTitleStack: View {
    let item: MediaItem

    @Environment(\.dismiss) private var dismiss
    @State private var path: [MediaItem] = []

    var body: some View {
        NavigationStack(path: $path) {
            NFTitlePage(item: item, isRoot: true, onClose: close, onOpen: open)
                .navigationDestination(for: MediaItem.self) { next in
                    NFTitlePage(item: next, isRoot: false, onClose: close, onOpen: open)
                }
        }
        .nfRouterHost()
        .preferredColorScheme(.dark)
    }

    private func open(_ next: MediaItem) {
        HapticManager.shared.lightImpact()
        path.append(next)
    }

    private func close() {
        dismiss()
    }
}

// MARK: - Model

@Observable
final class NFTitleModel {
    private(set) var payload: NFTitlePayload?
    private(set) var isLoading = false
    private(set) var didFail = false
    private(set) var selectedSeason: Int?
    private(set) var episodesBySeason: [Int: [NFEpisodePayload]] = [:]
    private(set) var loadingSeason: Int?
    private(set) var failedSeasons: Set<Int> = []

    @ObservationIgnored private var loadedKey: String?

    func load(_ item: MediaItem, preferredSeason: Int?) async {
        guard loadedKey != item.nfKey else { return }
        loadedKey = item.nfKey
        isLoading = true
        didFail = false

        do {
            let payload = try await NFCatalogService.title(type: item.nfType, id: item.id)
            self.payload = payload
            isLoading = false

            guard !item.isMovie else { return }

            let seasons = NFTitleFacts(item: item, payload: payload).playableSeasons.map(\.seasonNumber)
            let initial = preferredSeason.flatMap { seasons.contains($0) ? $0 : nil } ?? seasons.first
            if let initial {
                await selectSeason(initial, seriesId: item.id)
            }
        } catch {
            isLoading = false
            didFail = true
            loadedKey = nil
        }
    }

    func reload(_ item: MediaItem, preferredSeason: Int?) async {
        loadedKey = nil
        await load(item, preferredSeason: preferredSeason)
    }

    func selectSeason(_ number: Int, seriesId: Int) async {
        selectedSeason = number
        guard episodesBySeason[number] == nil else { return }

        loadingSeason = number
        failedSeasons.remove(number)

        if let episodes = try? await NFCatalogService.season(seriesId: seriesId, number: number) {
            episodesBySeason[number] = episodes
        } else {
            failedSeasons.insert(number)
        }

        if loadingSeason == number {
            loadingSeason = nil
        }
    }
}

// MARK: - Page

struct NFTitlePage: View {
    let item: MediaItem
    let isRoot: Bool
    let onClose: () -> Void
    let onOpen: (MediaItem) -> Void

    private enum Tab: String, CaseIterable, Identifiable {
        case episodes
        case moreLikeThis
        case trailers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .episodes: return "Episodes"
            case .moreLikeThis: return "More Like This"
            case .trailers: return "Trailers & More"
            }
        }
    }

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.nightflixAccent) private var accent
    @EnvironmentObject private var myList: MyListManager

    @State private var model = NFTitleModel()
    /// How far the top bar has faded in (quantised; see `topControls`).
    @State private var barProgress: CGFloat = 0
    @State private var selectedTab: Tab?
    @State private var trailer: NFIdentifiedURL?
    @State private var isOverviewExpanded = false
    @State private var seasonPicker: NFPickerRequest?

    private static let coordinateSpace = "nf-title-page"

    private var facts: NFTitleFacts {
        NFTitleFacts(item: item, payload: model.payload)
    }

    /// The title as a list item, upgraded with the payload's artwork once loaded.
    private var media: MediaItem {
        guard let payload = model.payload else { return item }
        return MediaItem(
            id: item.id,
            mediaType: item.mediaType,
            title: item.isMovie ? facts.title : nil,
            name: item.isMovie ? nil : facts.title,
            overview: facts.overview,
            releaseDate: item.isMovie ? (payload.releaseDate ?? item.releaseDate) : nil,
            firstAirDate: item.isMovie ? nil : (payload.firstAirDate ?? item.firstAirDate),
            posterPath: payload.posterPath ?? item.posterPath,
            backdropPath: payload.backdropPath ?? item.backdropPath,
            voteAverage: payload.voteAverage ?? item.voteAverage,
            voteCount: payload.voteCount ?? item.voteCount,
            genreIds: item.genreIds
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                NF.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroMedia(width: proxy.size.width)

                        content(width: proxy.size.width)
                            .padding(.horizontal, NF.gutter)
                            .padding(.top, 14)
                            .padding(.bottom, 40)
                    }
                    .nfScrollOffsetMarker(in: Self.coordinateSpace)
                }
                .coordinateSpace(name: Self.coordinateSpace)
                .scrollIndicators(.hidden)
                .onNFScrollOffsetChange { offset in
                    let heroHeight = (proxy.size.width * 9 / 16).rounded()
                    let progress = (min(max((offset - (heroHeight - 70)) / 40, 0), 1) * 20).rounded() / 20
                    if progress != barProgress {
                        barProgress = progress
                    }
                }

                topControls

                if let seasonPicker {
                    NFPickerOverlay(request: seasonPicker) {
                        self.seasonPicker = nil
                    }
                    .zIndex(10)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: item.nfKey) {
            await model.load(item, preferredSeason: app.resumeState(for: item)?.season)
            if let artwork = facts.artwork {
                app.library.artwork.store(artwork, for: item)
            }
        }
        .sheet(item: $trailer) { trailer in
            NFSafariView(url: trailer.url)
                .ignoresSafeArea()
        }
    }

    // MARK: Header

    private func heroMedia(width: CGFloat) -> some View {
        let height = (width * 9 / 16).rounded()
        let backdrop = NF.imageURL(media.backdropPath ?? facts.artwork?.textlessBackdropPath ?? media.posterPath, .backdropLarge)

        return Button {
            playTrailer()
        } label: {
            NFImage(url: backdrop)
                .frame(width: width, height: height)
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.35), .clear, .clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) {
                    if facts.trailer != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Preview")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55), in: Capsule())
                        .padding(12)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(facts.trailer == nil ? facts.title : "Play preview of \(facts.title)")
    }

    /// Back/close float over the artwork; once it scrolls away, a black bar with the
    /// title fades in behind them so content never runs under the status bar.
    private var topControls: some View {
        let progress = barProgress

        return HStack(spacing: 8) {
            if !isRoot {
                NFRoundIconButton(systemImage: "chevron.backward", accessibilityLabel: "Back") {
                    dismiss()
                }
            }

            Spacer(minLength: 0)

            NFRoundIconButton(systemImage: "xmark", accessibilityLabel: "Close") {
                onClose()
            }
        }
        .overlay {
            Text(facts.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 56)
                .opacity(progress)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background {
            Color.black
                .opacity(progress)
                .ignoresSafeArea(edges: .top)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(NF.hairline)
                        .frame(height: 0.5)
                        .opacity(progress)
                }
        }
    }

    // MARK: Body

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NFTitleLogo(item: item, maxWidth: min(width * 0.62, 300), maxHeight: 74, alignment: .leading, fallbackSize: 28)

            NFTitleMetaRow(facts: facts)
                .padding(.top, 12)

            if let rank = app.library.rank(for: item) {
                rankLine(rank)
                    .padding(.top, 10)
            }

            playButtons
                .padding(.top, 14)

            if let resume = app.resumeState(for: item), resume.hasProgress {
                resumeProgress(resume)
                    .padding(.top, 12)
            }

            if model.didFail {
                loadFailure
                    .padding(.top, 18)
            }

            overview
                .padding(.top, 14)

            credits
                .padding(.top, 10)

            actionRow
                .padding(.top, 20)

            tabBar
                .padding(.top, 22)

            tabContent(width: width)
                .padding(.top, 16)
        }
    }

    private func rankLine(_ rank: NFRank) -> some View {
        HStack(spacing: 8) {
            NFTop10CornerBadge()
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            Text("#\(rank.rank) in \(rank.listName)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private var playButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let date = facts.upcomingDate {
                Text(date.nfComingLabel(isMovie: item.isMovie))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 2)

                NFReminderButton(item: media, date: date)
            } else {
                Button {
                    play()
                } label: {
                    NFPrimaryButtonLabel(title: playTitle)
                }
                .buttonStyle(NFPressableStyle(scale: 0.98))
            }

            if facts.trailer != nil {
                Button {
                    playTrailer()
                } label: {
                    NFSecondaryButtonLabel(title: "Trailer", systemImage: "play.rectangle")
                }
                .buttonStyle(NFPressableStyle(scale: 0.98))
            }
        }
    }

    private func resumeProgress(_ resume: NFResumeState) -> some View {
        HStack(spacing: 10) {
            NFProgressBar(fraction: resume.fraction ?? 0, tint: accent, height: 3)
                .frame(maxWidth: 150)
                .clipShape(Capsule())

            if let line = resume.detailLine {
                Text(line)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NF.textSecondary)
            }
        }
    }

    private var loadFailure: some View {
        HStack(spacing: 10) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(NF.textSecondary)
            Text("Some details didn't load.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NF.textSecondary)
            Spacer()
            Button("Retry") {
                Task { await model.reload(item, preferredSeason: app.resumeState(for: item)?.season) }
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
        }
        .padding(12)
        .background(NF.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var overview: some View {
        let text = facts.overview

        if !text.isEmpty {
            Text(text)
                .font(.system(size: 14.5))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .lineLimit(isOverviewExpanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isOverviewExpanded.toggle()
                    }
                }
        } else if model.isLoading {
            VStack(alignment: .leading, spacing: 6) {
                TextLineSkeletonView(height: 11)
                TextLineSkeletonView(height: 11)
                TextLineSkeletonView(width: 180, height: 11)
            }
        }
    }

    @ViewBuilder
    private var credits: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cast = facts.castLine {
                creditText(label: "Starring", value: cast)
            }

            if let creator = facts.creatorLine {
                creditText(label: creator.label, value: creator.names)
            }
        }
    }

    private func creditText(label: String, value: String) -> some View {
        (Text("\(label): ").foregroundStyle(NF.textTertiary) + Text(value).foregroundStyle(NF.textSecondary))
            .font(.system(size: 12.5))
            .lineLimit(2)
    }

    private var actionRow: some View {
        HStack(spacing: 30) {
            Button {
                HapticManager.shared.success()
                myList.toggle(MyListItem(media))
            } label: {
                NFIconActionLabel(title: "My List", systemImage: isInMyList ? "checkmark" : "plus")
            }

            Button {
                HapticManager.shared.selection()
                app.library.toggleLike(media)
            } label: {
                NFIconActionLabel(
                    title: isLiked ? "Rated" : "Rate",
                    systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup"
                )
            }

            if let url = item.tmdbWebURL {
                ShareLink(item: url, subject: Text(facts.title), message: Text("Watch \(facts.title) on Nightflix")) {
                    NFIconActionLabel(title: "Share", systemImage: "paperplane")
                }
            }

            Spacer(minLength: 0)
        }
        .buttonStyle(NFPressableStyle(scale: 0.92))
        .padding(.leading, -8)
    }

    // MARK: Tabs

    private var availableTabs: [Tab] {
        var tabs: [Tab] = []
        if !item.isMovie { tabs.append(.episodes) }
        tabs.append(.moreLikeThis)
        if !facts.videos.isEmpty { tabs.append(.trailers) }
        return tabs
    }

    private var activeTab: Tab {
        if let selectedTab, availableTabs.contains(selectedTab) {
            return selectedTab
        }
        return availableTabs.first ?? .moreLikeThis
    }

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 22) {
                ForEach(availableTabs) { tab in
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Rectangle()
                                .fill(activeTab == tab ? accent : Color.clear)
                                .frame(height: 4)

                            Text(tab.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(activeTab == tab ? Color.white : NF.textTertiary)
                                .fixedSize()
                        }
                        .fixedSize()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(NF.hairline)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func tabContent(width: CGFloat) -> some View {
        switch activeTab {
        case .episodes:
            episodesSection
        case .moreLikeThis:
            moreLikeThisGrid(width: width)
        case .trailers:
            trailersList
        }
    }

    // MARK: Episodes

    @ViewBuilder
    private var episodesSection: some View {
        let seasons = facts.playableSeasons

        VStack(alignment: .leading, spacing: 18) {
            if seasons.count > 1 {
                Button {
                    presentSeasonPicker(seasons)
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedSeasonName(seasons))
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(NF.surfaceRaised, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            } else if let only = seasons.first {
                Text(only.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            episodeList
        }
    }

    @ViewBuilder
    private var episodeList: some View {
        if let season = model.selectedSeason {
            if let episodes = model.episodesBySeason[season] {
                if episodes.isEmpty {
                    Text("No episodes listed yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(NF.textTertiary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        ForEach(episodes) { episode in
                            episodeRow(episode)
                        }
                    }
                }
            } else if model.failedSeasons.contains(season) {
                Button("Couldn't load episodes. Tap to retry.") {
                    Task { await model.selectSeason(season, seriesId: item.id) }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(NF.textSecondary)
            } else {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonView(cornerRadius: 4)
                            .frame(width: 132, height: 74)
                        VStack(alignment: .leading, spacing: 8) {
                            TextLineSkeletonView(width: 140, height: 11)
                            TextLineSkeletonView(width: 60, height: 9)
                        }
                    }
                }
            }
        } else if model.isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity)
        }
    }

    private func episodeRow(_ episode: NFEpisodePayload) -> some View {
        let resume = app.resumeState(for: item)
        let isTracked = resume?.season == episode.seasonNumber && resume?.episode == episode.episodeNumber
        let aired = episode.hasAired

        return Button {
            guard aired else { return }
            playEpisode(episode)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    ZStack(alignment: .bottom) {
                        NFImage(url: NF.imageURL(episode.stillPath ?? media.backdropPath, .still))
                            .frame(width: 132, height: 74)

                        if aired {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.black.opacity(0.45), in: Circle())
                                .overlay { Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2) }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        if isTracked, let fraction = resume?.fraction, fraction > 0.01 {
                            NFProgressBar(fraction: fraction, tint: accent, height: 3)
                        }
                    }
                    .frame(width: 132, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(episode.episodeNumber). \(episode.displayName)")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(episodeSubtitle(episode, aired: aired))
                            .font(.system(size: 12))
                            .foregroundStyle(NF.textTertiary)
                    }

                    Spacer(minLength: 0)
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.system(size: 13))
                        .foregroundStyle(NF.textSecondary)
                        .lineSpacing(1.5)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .opacity(aired ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(NFPressableStyle(scale: 0.99))
        .accessibilityLabel("Episode \(episode.episodeNumber), \(episode.displayName)")
    }

    private func episodeSubtitle(_ episode: NFEpisodePayload, aired: Bool) -> String {
        if !aired, let date = NF.date(fromTMDB: episode.airDate) {
            return "Coming \(date.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return NF.runtimeText(minutes: episode.runtime) ?? ""
    }

    private func selectedSeasonName(_ seasons: [NFSeasonSummary]) -> String {
        let number = model.selectedSeason ?? seasons.first?.seasonNumber
        return seasons.first { $0.seasonNumber == number }?.displayName ?? "Season"
    }

    private func presentSeasonPicker(_ seasons: [NFSeasonSummary]) {
        HapticManager.shared.selection()
        seasonPicker = NFPickerRequest(
            options: seasons.map { NFPickerOption(id: String($0.seasonNumber), title: $0.displayName) },
            selectedID: model.selectedSeason.map(String.init)
        ) { selected in
            guard let number = Int(selected) else { return }
            Task { await model.selectSeason(number, seriesId: item.id) }
        }
    }

    // MARK: More Like This / Trailers

    @ViewBuilder
    private func moreLikeThisGrid(width: CGFloat) -> some View {
        let items = facts.moreLikeThis
        let spacing: CGFloat = 8
        let columnWidth = ((width - NF.gutter * 2 - spacing * 2) / 3).rounded(.down)

        if items.isEmpty {
            if model.isLoading {
                NFPosterRowSkeleton(width: columnWidth, count: 3)
                    .padding(.horizontal, -NF.gutter)
            } else {
                Text("No similar titles yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(NF.textTertiary)
            }
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(columnWidth), spacing: spacing), count: 3),
                alignment: .leading,
                spacing: spacing
            ) {
                ForEach(items.prefix(18), id: \.nfKey) { next in
                    NFPosterButton(item: next, width: columnWidth) { selected in
                        onOpen(selected)
                    }
                }
            }
        }
    }

    private var trailersList: some View {
        LazyVStack(alignment: .leading, spacing: 18) {
            ForEach(facts.videos.prefix(12)) { video in
                Button {
                    open(video)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        NFImage(url: video.thumbnailURL)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.5), in: Circle())
                                    .overlay { Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2) }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(video.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(video.type)
                            .font(.system(size: 12))
                            .foregroundStyle(NF.textTertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NFPressableStyle(scale: 0.99))
            }
        }
    }

    // MARK: Actions

    private var isInMyList: Bool {
        myList.contains(mediaType: item.isMovie ? .movie : .tv, tmdbId: item.id)
    }

    private var isLiked: Bool {
        app.library.isLiked(item)
    }

    private var playTitle: String {
        guard let resume = app.resumeState(for: item), resume.hasProgress else { return "Play" }
        if let label = resume.episodeLabel {
            return "Resume \(label)"
        }
        return "Resume"
    }

    private func play() {
        if item.isMovie {
            app.play(media, router: router)
            return
        }

        if app.continueEntry(for: item) != nil {
            app.play(media, router: router)
            return
        }

        // Start a new series at the first episode of its first regular season.
        let season = facts.playableSeasons.first?.seasonNumber ?? 1
        let firstEpisode = model.episodesBySeason[season]?.first
        guard let watchItem = app.episodeItem(
            seriesId: item.id,
            seriesName: facts.title,
            posterPath: media.posterPath,
            season: season,
            episode: firstEpisode?.episodeNumber ?? 1,
            episodeName: firstEpisode?.name
        ) else {
            HapticManager.shared.error()
            return
        }

        app.play(watchItem, router: router)
    }

    private func playEpisode(_ episode: NFEpisodePayload) {
        guard let watchItem = app.episodeItem(
            seriesId: item.id,
            seriesName: facts.title,
            posterPath: media.posterPath,
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            episodeName: episode.name
        ) else {
            HapticManager.shared.error()
            return
        }

        app.play(watchItem, router: router)
    }

    private func playTrailer() {
        guard let video = facts.trailer else { return }
        open(video)
    }

    private func open(_ video: NFVideoPayload) {
        guard let url = video.watchURL else { return }
        HapticManager.shared.lightImpact()
        trailer = NFIdentifiedURL(url: url)
    }
}
