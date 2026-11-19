import SwiftUI

/// Home: a translucent header (wordmark, search, filter chips) over an ambient-tinted
/// hero card, followed by lazily loaded rails — Continue Watching, Top 10s, My List,
/// genre rails and "Because You Watched" recommendations.
struct NFHomeView: View {
    let scrollToTopToken: Int

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @Environment(\.nightflixAccent) private var accent
    @EnvironmentObject private var myList: MyListManager

    /// 0 at the top of the feed → 1 once the header backing is fully in. Quantised so
    /// scrolling only re-renders the screen while the header is fading.
    @State private var headerProgress: CGFloat = 0
    @State private var ambient = Color(white: 0.16)

    private static let barHeight: CGFloat = 50
    private static let chipsHeight: CGFloat = 44
    private static let headerHeight = barHeight + chipsHeight
    private static let coordinateSpace = "nf-home"

    private var feed: NFFeedModel { app.feed }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let width = proxy.size.width
            let heroSize = heroSize(width: width, height: proxy.size.height)

            ZStack(alignment: .top) {
                NF.canvas.ignoresSafeArea()

                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: topInset + Self.headerHeight + 6)
                                .id("top")

                            hero(size: heroSize, width: width)

                            LazyVStack(alignment: .leading, spacing: 26) {
                                ForEach(feed.rows) { row in
                                    rowView(row, width: width)
                                }
                            }
                            .padding(.top, 30)
                            .padding(.bottom, 36)
                        }
                        .background(alignment: .top) {
                            ambientBackdrop(height: topInset + Self.headerHeight + heroSize.height + 160)
                        }
                        .nfScrollOffsetMarker(in: Self.coordinateSpace)
                    }
                    .coordinateSpace(name: Self.coordinateSpace)
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                    .onNFScrollOffsetChange { offset in
                        let progress = (min(max((offset - 8) / 70, 0), 1) * 20).rounded() / 20
                        if progress != headerProgress {
                            headerProgress = progress
                        }
                    }
                    .onChange(of: scrollToTopToken) { _, _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scroller.scrollTo("top", anchor: .top)
                        }
                    }
                    .onChange(of: feed.scopeKey) { _, _ in
                        scroller.scrollTo("top", anchor: .top)
                    }
                }

                header(topInset: topInset)
            }
        }
        .task(id: feed.scopeKey) {
            await feed.loadHero()
        }
        .task(id: app.history.items.first?.id) {
            feed.updatePersonalization(history: app.history.items)
        }
    }

    // MARK: - Header

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                NFWordmark()

                Spacer()

                Button {
                    router.openSearch()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Search")
            }
            .padding(.leading, NF.gutter)
            .padding(.trailing, 8)
            .frame(height: Self.barHeight)

            chips
                .frame(height: Self.chipsHeight)
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.5)
                ambient.opacity(0.22)
            }
            .ignoresSafeArea(edges: .top)
            .opacity(headerProgress)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)
                .opacity(headerProgress)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if feed.scope != .all || feed.category != nil {
                    NFClearChip {
                        withAnimation(.snappy(duration: 0.25)) {
                            feed.setScope(.all, category: nil)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                if feed.scope == .all {
                    NFChip(title: "Series") {
                        select(scope: .series)
                    }
                    NFChip(title: "Films") {
                        select(scope: .films)
                    }
                } else {
                    NFChip(title: feed.scope.label, isSelected: true) {
                        select(scope: .all)
                    }
                }

                NFChip(
                    title: feed.category?.name ?? "Categories",
                    trailingSystemImage: "chevron.down",
                    isSelected: feed.category != nil
                ) {
                    presentCategories()
                }
            }
            .padding(.horizontal, NF.gutter)
            .animation(.snappy(duration: 0.25), value: feed.scopeKey)
        }
        .scrollIndicators(.hidden)
    }

    private func select(scope: NFBrowseScope) {
        let keepsCategory = feed.category.map { $0.supports(scope) } ?? false
        withAnimation(.snappy(duration: 0.25)) {
            feed.setScope(scope, category: keepsCategory ? feed.category : nil)
        }
    }

    private func presentCategories() {
        let model = feed
        let scope = model.scope
        let categories = NFCategory.catalog.filter { $0.supports(scope) }
        let homeTitle = scope == .all ? "Home" : "All \(scope.label)"

        app.picker = NFPickerRequest(
            options: [NFPickerOption(id: "home", title: homeTitle)]
                + categories.map { NFPickerOption(id: $0.id, title: $0.name) },
            selectedID: model.category?.id ?? "home"
        ) { selected in
            let category = categories.first { $0.id == selected }
            model.setScope(scope, category: category)
        }
    }

    // MARK: - Ambient background

    /// The hero's colour washed across the top of the feed, fading into black.
    private func ambientBackdrop(height: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: ambient.opacity(0.95), location: 0),
                .init(color: ambient.opacity(0.7), location: 0.35),
                .init(color: ambient.opacity(0.28), location: 0.7),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height + 600)
        .padding(.top, -600)
        .allowsHitTesting(false)
    }

    // MARK: - Hero

    private func heroSize(width: CGFloat, height: CGFloat) -> CGSize {
        if width > 700 {
            let heroWidth = width - NF.gutter * 2
            return CGSize(width: heroWidth, height: min(heroWidth * 9 / 16, height * 0.6))
        }

        let cardWidth = width - NF.gutter * 2
        return CGSize(width: cardWidth, height: min(cardWidth * 1.42, height * 0.66))
    }

    @ViewBuilder
    private func hero(size: CGSize, width: CGFloat) -> some View {
        if let item = feed.hero {
            NFHeroCard(
                item: item,
                artwork: feed.heroArtwork,
                size: size,
                isWide: width > 700,
                onAmbientColor: { color in
                    withAnimation(.easeInOut(duration: 0.7)) {
                        ambient = color
                    }
                }
            )
            .id(item.nfKey)
            .transition(.opacity)
        } else if feed.heroFailed {
            VStack(spacing: 12) {
                Text("We couldn't load the featured title.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(NF.textSecondary)
                Button {
                    Task { await feed.loadHero() }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: NF.buttonCorner))
                }
                .buttonStyle(.plain)
            }
            .frame(width: size.width, height: size.height * 0.55)
            .background(NF.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            SkeletonView(cornerRadius: 10)
                .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: NFRow, width: CGFloat) -> some View {
        switch row.style {
        case .continueWatching:
            continueWatchingRow(row, width: width)
        case .myList:
            myListRow(row, width: width)
        case .posters, .top10:
            catalogRow(row, width: width)
        }
    }

    @ViewBuilder
    private func catalogRow(_ row: NFRow, width: CGFloat) -> some View {
        let posterWidth = NF.posterWidth(for: width)
        let items = feed.items(for: row)

        Group {
            if let items {
                if !items.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        NFRowHeader(title: row.title)
                        railScroller {
                            ForEach(Array(items.enumerated()), id: \.element.nfKey) { index, item in
                                if row.style == .top10 {
                                    NFTop10Card(rank: index + 1, item: item, posterWidth: (posterWidth * 0.94).rounded())
                                } else {
                                    NFPosterButton(item: item, width: posterWidth, badges: badges(for: item, in: row))
                                }
                            }
                        }
                    }
                }
            } else if feed.failedRows.contains(row.id) {
                VStack(alignment: .leading, spacing: 10) {
                    NFRowHeader(title: row.title)
                    Button {
                        Task { await feed.retry(row) }
                    } label: {
                        Label("Couldn't load this row. Tap to retry.", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(NF.textSecondary)
                            .padding(.horizontal, NF.gutter)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    NFRowHeader(title: row.title)
                    NFPosterRowSkeleton(width: posterWidth)
                }
            }
        }
        .task {
            await feed.load(row)
        }
    }

    private func railScroller<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 8) {
                content()
            }
            .padding(.horizontal, NF.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func badges(for item: MediaItem, in row: NFRow) -> [NFPosterBadge] {
        var badges: [NFPosterBadge] = []

        if app.library.rank(for: item) != nil {
            badges.append(.top10)
        }

        if !item.isMovie, feed.onAirKeys.contains(item.nfKey), row.id != "on-the-air" {
            badges.append(.newEpisodes)
        } else if let date = item.releaseDateValue,
                  date <= Date(),
                  date > Date().addingTimeInterval(-35 * 24 * 60 * 60) {
            badges.append(.newRelease)
        }

        return badges
    }

    // MARK: Continue Watching

    @ViewBuilder
    private func continueWatchingRow(_ row: NFRow, width: CGFloat) -> some View {
        let entries = app.continueWatching.items.filter { entry in
            guard feed.category == nil else { return false }
            switch feed.scope {
            case .all: return true
            case .series: return entry.type == .tv
            case .films: return entry.type == .movie
            }
        }

        if !entries.isEmpty {
            let cardWidth = NF.posterWidth(for: width)

            VStack(alignment: .leading, spacing: 10) {
                NFRowHeader(title: row.title)
                railScroller {
                    ForEach(entries) { entry in
                        NFContinueCard(
                            entry: entry,
                            width: cardWidth,
                            onPlay: { resume(entry) },
                            onInfo: { router.preview(media(for: entry)) },
                            onRemove: {
                                HapticManager.shared.lightImpact()
                                withAnimation(.snappy) {
                                    app.continueWatching.markFinished(type: entry.type, tmdbId: entry.tmdbId)
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private func media(for entry: ContinueWatchingItem) -> MediaItem {
        MediaItem.make(
            id: entry.tmdbIntId ?? 0,
            type: entry.type,
            title: entry.title,
            posterPath: entry.posterPath
        )
    }

    private func resume(_ entry: ContinueWatchingItem) {
        guard let id = entry.tmdbIntId else { return }

        let item: WatchItem?
        switch entry.type {
        case .movie:
            item = app.movieItem(id: id, title: entry.title, posterPath: entry.posterPath)
        case .tv:
            item = app.episodeItem(
                seriesId: id,
                seriesName: entry.title,
                posterPath: entry.posterPath,
                season: entry.season ?? 1,
                episode: entry.episode ?? 1,
                episodeName: entry.episodeName
            )
        }

        guard let item else {
            HapticManager.shared.error()
            return
        }

        app.play(item, router: router)
    }

    // MARK: My List

    @ViewBuilder
    private func myListRow(_ row: NFRow, width: CGFloat) -> some View {
        let items = myList.items.filter { saved in
            guard feed.category == nil else { return false }
            switch feed.scope {
            case .all: return true
            case .series: return saved.mediaType == .tv
            case .films: return saved.mediaType == .movie
            }
        }

        if !items.isEmpty {
            let posterWidth = NF.posterWidth(for: width)

            VStack(alignment: .leading, spacing: 10) {
                NFRowHeader(title: row.title)
                railScroller {
                    ForEach(items) { saved in
                        NFPosterButton(item: saved.mediaItem, width: posterWidth)
                    }
                }
            }
        }
    }
}

// MARK: - Hero card

/// The marquee: textless key art (when TMDB has it) with the title logo, genre tags and
/// Play / My List. Tapping the art opens the quick preview.
struct NFHeroCard: View {
    let item: MediaItem
    let artwork: NFArtwork?
    let size: CGSize
    let isWide: Bool
    let onAmbientColor: (Color) -> Void

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @EnvironmentObject private var myList: MyListManager

    private var usesTextlessArt: Bool {
        isWide || artwork?.textlessPosterPath != nil
    }

    private var artURL: URL? {
        if isWide {
            return NF.imageURL(artwork?.textlessBackdropPath ?? item.backdropPath, .backdropLarge)
        }
        return NF.imageURL(artwork?.textlessPosterPath ?? item.posterPath, .posterLarge)
    }

    var body: some View {
        ZStack(alignment: isWide ? .bottomLeading : .bottom) {
            Button {
                router.preview(item)
            } label: {
                NFImage(url: artURL, alignment: .top)
                    .frame(width: size.width, height: size.height)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.displayTitle), more info")

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: isWide ? 0.35 : 0.45),
                    .init(color: .black.opacity(0.45), location: 0.72),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            info
                .padding(.horizontal, isWide ? 28 : 16)
                .padding(.bottom, isWide ? 26 : 16)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
        }
        .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
        .task(id: artURL) {
            guard let artURL,
                  let color = await NFImagePipeline.shared.ambientColor(for: artURL) else { return }
            onAmbientColor(Color(uiColor: color))
        }
    }

    private var info: some View {
        VStack(alignment: isWide ? .leading : .center, spacing: 12) {
            if usesTextlessArt {
                NFTitleLogo(
                    item: item,
                    maxWidth: isWide ? min(size.width * 0.4, 420) : size.width * 0.72,
                    maxHeight: isWide ? 120 : size.height * 0.19,
                    alignment: isWide ? .leading : .center,
                    fallbackSize: isWide ? 44 : 34
                )
            }

            if !item.nfGenreTags.isEmpty {
                Text(item.nfGenreTags.joined(separator: "  •  "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 4)
            }

            HStack(spacing: 10) {
                Button {
                    app.play(item, router: router)
                } label: {
                    NFPrimaryButtonLabel(title: playTitle, height: 40)
                }
                .buttonStyle(NFPressableStyle())

                Button {
                    HapticManager.shared.success()
                    myList.toggle(MyListItem(item))
                } label: {
                    NFSecondaryButtonLabel(
                        title: "My List",
                        systemImage: isInMyList ? "checkmark" : "plus",
                        height: 40
                    )
                }
                .buttonStyle(NFPressableStyle())
            }
            .frame(maxWidth: isWide ? 360 : .infinity)
        }
    }

    private var playTitle: String {
        guard let resume = app.resumeState(for: item), resume.hasProgress else { return "Play" }
        return "Resume"
    }

    private var isInMyList: Bool {
        myList.contains(mediaType: item.isMovie ? .movie : .tv, tmdbId: item.id)
    }
}
