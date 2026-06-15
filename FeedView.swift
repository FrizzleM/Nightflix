import SwiftUI

struct FeedView: View {
    private let homeScrollCoordinateSpace = "home-feed-scroll"
    private let homeTopAnchorId = "home-top-anchor"
    private let homeSearchAnchorId = "home-search-anchor"

    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    @ObservedObject var myListManager: MyListManager
    let animationTrigger: Int
    let homeResetTrigger: Int
    let showNightflixTitle: Bool
    let shouldAnimateNightflixTitle: Bool
    let startupContentAnimationReady: Bool
    @Binding var selectedHomeMenuDestination: HomeMenuDestination?
    let onOpenHomeMenu: () -> Void

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = FeedViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var selectedItem: WatchItem?
    @State private var selectedSeries: SeriesSelection?
    @State private var selectedDetailItem: MediaItem?
    @State private var playErrorMessage: String?
    @State private var showContent = false
    @State private var hasHandledStartupContentAnimation = false
    @State private var scrollOffset: CGFloat = 0
    @State private var searchShortcutRequest = 0
    @State private var searchFocusRequest = 0
    @State private var homeResetRequest = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    NightFlixStyle.backgroundColor.ignoresSafeArea()

                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            scrollOffsetReader
                                .id(homeTopAnchorId)

                            LazyVStack(alignment: .leading, spacing: NightflixLayout.sectionSpacing) {
                                feedSearchBar
                                    .id(homeSearchAnchorId)
                                    .padding(.horizontal, NightflixLayout.screenPadding)

                                if let playErrorMessage {
                                    messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
                                        .padding(.horizontal, NightflixLayout.screenPadding)
                                }

                                if searchViewModel.hasActiveQuery {
                                    MediaSearchResultsView(
                                        title: "Search Results",
                                        viewModel: searchViewModel,
                                        playErrorMessage: nil,
                                        isEntranceVisible: showContent,
                                        baseDelay: 0.42,
                                        animationsEnabled: contentAnimationsEnabled,
                                        onSelectResult: showDetail
                                    )
                                    .padding(.horizontal, NightflixLayout.screenPadding)
                                } else {
                                    featuredHeroSection(baseDelay: 0.42)
                                    continueWatchingSection(baseDelay: 0.5)
                                    top10Section(baseDelay: 0.56)
                                    interleavedSections(baseDelay: 0.62)
                                }
                            }
                            .padding(.top, HomeStickyHeaderView.scrollContentTopPadding(topSafeArea: geometry.safeAreaInsets.top))
                            .padding(.bottom, 120)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .coordinateSpace(name: homeScrollCoordinateSpace)
                        .ignoresSafeArea(edges: .top)
                        .trackHomeScrollOffset { newOffset in
                            updateScrollOffset(newOffset)
                        }
                        .onPreferenceChange(HomeScrollOffsetPreferenceKey.self) { newOffset in
                            updateScrollOffset(newOffset)
                        }
                        .refreshable {
                            HapticManager.shared.mediumImpact()
                            await viewModel.refresh()
                            await viewModel.loadPersonalizedRows(from: historyManager.items, force: true)
                            if feedErrorSignature.isEmpty {
                                HapticManager.shared.success()
                            } else {
                                HapticManager.shared.error()
                            }
                        }
                        .onChange(of: searchShortcutRequest) { _, _ in
                            scrollToSearchBar(with: scrollProxy)
                        }
                        .onChange(of: homeResetRequest) { _, _ in
                            resetToInitialHomeScreen(with: scrollProxy)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HomeStickyHeaderView(
                        scrollOffset: scrollOffset,
                        topSafeArea: geometry.safeAreaInsets.top,
                        showTitle: showNightflixTitle,
                        shouldAnimateTitle: shouldAnimateNightflixTitle,
                        showMenuButton: showContent,
                        showSearchShortcut: shouldShowSearchShortcut(topSafeArea: geometry.safeAreaInsets.top),
                        animationsEnabled: contentAnimationsEnabled,
                        onHomeTitle: requestHomeReset,
                        onSearchShortcut: requestSearchBarScroll,
                        onOpenMenu: onOpenHomeMenu
                    )
                    .zIndex(100)
                    .ignoresSafeArea(edges: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedItem) { item in
                PlayerView(item: item, continueWatchingManager: continueWatchingManager)
            }
            .navigationDestination(item: $selectedSeries) { series in
                SeriesDetailView(
                    seriesId: series.id,
                    fallbackName: series.name,
                    fallbackPosterPath: series.posterPath,
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager
                )
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                MediaDetailView(
                    item: item,
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager,
                    myListManager: myListManager
                )
            }
            .navigationDestination(item: $selectedHomeMenuDestination) { destination in
                switch destination {
                case .myList:
                    MyListView(
                        myListManager: myListManager,
                        historyManager: historyManager,
                        continueWatchingManager: continueWatchingManager
                    )
                case .categories:
                    CategoriesView(
                        historyManager: historyManager,
                        continueWatchingManager: continueWatchingManager,
                        myListManager: myListManager
                    )
                case .settings:
                    SettingsView(
                        historyManager: historyManager,
                        continueWatchingManager: continueWatchingManager
                    )
                }
            }
        }
        .onAppear {
            prepareStartupContentAnimation()
        }
        .onChange(of: startupContentAnimationReady) { _, isReady in
            if isReady {
                prepareStartupContentAnimation()
            }
        }
        .onChange(of: animationTrigger) { _, _ in
            replayHomeContentAnimationIfNeeded()
        }
        .onChange(of: homeResetTrigger) { _, _ in
            requestHomeReset()
        }
        .onChange(of: reduceMotion) { _, _ in
            keepContentVisible()
        }
        .onChange(of: settings.animationMode) { _, _ in
            keepContentVisible()
            hasHandledStartupContentAnimation = true
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .task(id: historyManager.items) {
            await viewModel.loadPersonalizedRows(from: historyManager.items)
        }
        .tint(NightFlixStyle.accentColor)
        .onChange(of: feedErrorSignature) { _, newValue in
            if !newValue.isEmpty {
                HapticManager.shared.error()
            }
        }
    }

    private var feedSearchBar: some View {
        MediaSearchBar(query: searchQueryBinding, focusRequest: searchFocusRequest)
            .frame(maxWidth: .infinity)
            .nightflixEntrance(isVisible: showContent, delay: 0.35, yOffset: 14, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
    }

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: HomeScrollOffsetPreferenceKey.self,
                value: -proxy.frame(in: .named(homeScrollCoordinateSpace)).minY
            )
        }
        .frame(height: 0)
    }

    @ViewBuilder
    private func featuredHeroSection(baseDelay: Double) -> some View {
        if viewModel.isLoadingFeaturedHero && viewModel.featuredHeroItem == nil {
            HeroBannerPlaceholderView()
                .frame(maxWidth: .infinity)
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 14, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
        } else if let item = viewModel.featuredHeroItem {
            HeroBannerView(
                item: item,
                myListManager: myListManager,
                onPlay: playHeroItem,
                onMyList: toggleHeroMyList,
                onMoreInfo: showHeroDetail
            )
            .frame(maxWidth: .infinity)
            .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 14, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
        }
    }

    @ViewBuilder
    private func continueWatchingSection(baseDelay: Double) -> some View {
        if !continueWatchingManager.items.isEmpty {
            rowSection(title: "Continue Watching", baseDelay: baseDelay, coordinateSpaceName: "continue-watching-row") {
                ForEach(Array(continueWatchingManager.items.enumerated()), id: \.element.id) { index, item in
                    ContinueWatchingTile(
                        title: item.title,
                        subtitle: continueWatchingSubtitle(item),
                        url: item.posterURL,
                        progress: item.progressFraction,
                        action: { playContinueWatching(item) }
                    )
                    .scrollHapticCard(index: index, coordinateSpaceName: "continue-watching-row")
                    .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled, onceKey: cardOnceKey("continue-watching-row", item.id.uuidString))
                }
            }
        }
    }

    /// Renders the personalized "Because you watched" rows interleaved with the
    /// standard category rails so the two alternate down the feed.
    @ViewBuilder
    private func interleavedSections(baseDelay: Double) -> some View {
        if viewModel.personalizedRows.isEmpty && viewModel.isLoadingPersonalizedRows {
            personalizedSkeletonRow(baseDelay: baseDelay)
        }

        ForEach(Array(interleavedFeedBlocks.enumerated()), id: \.element.id) { index, block in
            let delay = blockDelay(index, baseDelay: baseDelay)

            switch block {
            case .personalized(let row):
                personalizedRowView(row, baseDelay: delay)
            case let .category(title, section):
                feedSection(title: title, section: section, baseDelay: delay)
            }
        }
    }

    @ViewBuilder
    private func personalizedRowView(_ row: PersonalizedRow, baseDelay: Double) -> some View {
        let coordinateSpaceName = "because-you-watched-\(row.id)"

        rowSection(
            title: "Because you watched \(row.seedTitle)",
            baseDelay: baseDelay,
            coordinateSpaceName: coordinateSpaceName
        ) {
            ForEach(Array(row.items.enumerated()), id: \.element) { index, item in
                PosterCard(
                    url: item.posterURL,
                    accessibilityLabel: item.title,
                    action: { selectedDetailItem = item.mediaItem }
                )
                .scrollHapticCard(index: index, coordinateSpaceName: coordinateSpaceName)
                .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled, onceKey: cardOnceKey(coordinateSpaceName, String(item.id)))
            }
        }
    }

    @ViewBuilder
    private func personalizedSkeletonRow(baseDelay: Double) -> some View {
        VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
            SectionHeaderView(title: "Because you watched…")
                .padding(.horizontal, NightflixLayout.screenPadding)
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled, onceKey: sectionTitleOnceKey("Because you watched…"))

            loadingRow
                .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func top10Section(baseDelay: Double) -> some View {
        let section = viewModel.trending
        let coordinateSpaceName = "top10-row"

        VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
            SectionHeaderView(title: "Top 10 This Week")
                .padding(.horizontal, NightflixLayout.screenPadding)
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled, onceKey: sectionTitleOnceKey("Top 10 This Week"))

            if let errorMessage = section.errorMessage, section.items.isEmpty {
                messageRow(errorMessage, systemImage: "info.circle.fill")
                    .padding(.horizontal, NightflixLayout.screenPadding)
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, animationsEnabled: contentAnimationsEnabled)
            } else if section.isLoading && section.items.isEmpty {
                loadingRow
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(section.items.prefix(10).enumerated()), id: \.element) { index, item in
                            Top10PosterCard(
                                rank: index + 1,
                                url: item.posterURL,
                                accessibilityLabel: item.title,
                                action: { selectedDetailItem = item.mediaItem }
                            )
                            .scrollHapticCard(index: index, coordinateSpaceName: coordinateSpaceName)
                            .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled, onceKey: cardOnceKey(coordinateSpaceName, String(item.id)))
                        }
                    }
                    .padding(.horizontal, NightflixLayout.screenPadding)
                }
                .frame(maxWidth: .infinity)
                .horizontalScrollHaptics(coordinateSpaceName: coordinateSpaceName, isEnabled: showContent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func feedSection(title: String, section: FeedSection, baseDelay: Double) -> some View {
        let coordinateSpaceName = "feed-row-\(title)"

        VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
            SectionHeaderView(title: title)
                .padding(.horizontal, NightflixLayout.screenPadding)
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled, onceKey: sectionTitleOnceKey(title))

            if let errorMessage = section.errorMessage {
                messageRow(errorMessage, systemImage: "info.circle.fill")
                    .padding(.horizontal, NightflixLayout.screenPadding)
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, animationsEnabled: contentAnimationsEnabled)
            } else if section.isLoading && section.items.isEmpty {
                loadingRow
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: NightflixLayout.rowItemSpacing) {
                        ForEach(Array(section.items.enumerated()), id: \.element) { index, item in
                            PosterCard(
                                url: item.posterURL,
                                accessibilityLabel: item.title,
                                action: { selectedDetailItem = item.mediaItem }
                            )
                            .scrollHapticCard(index: index, coordinateSpaceName: coordinateSpaceName)
                            .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled, onceKey: cardOnceKey(coordinateSpaceName, String(item.id)))
                        }
                    }
                    .padding(.horizontal, NightflixLayout.screenPadding)
                }
                .frame(maxWidth: .infinity)
                .horizontalScrollHaptics(coordinateSpaceName: coordinateSpaceName, isEnabled: showContent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Shared chrome for a horizontally-scrolling, edge-to-edge poster row.
    @ViewBuilder
    private func rowSection<Content: View>(
        title: String,
        baseDelay: Double,
        coordinateSpaceName: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: NightflixLayout.sectionHeaderSpacing) {
            SectionHeaderView(title: title)
                .padding(.horizontal, NightflixLayout.screenPadding)
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled, onceKey: sectionTitleOnceKey(title))

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: NightflixLayout.rowItemSpacing) {
                    content()
                }
                .padding(.horizontal, NightflixLayout.screenPadding)
            }
            .frame(maxWidth: .infinity)
            .horizontalScrollHaptics(coordinateSpaceName: coordinateSpaceName, isEnabled: showContent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: NightflixLayout.rowItemSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    PosterSkeletonView(
                        width: NightflixLayout.posterWidth,
                        height: NightflixLayout.posterHeight,
                        cornerRadius: NightflixLayout.posterCornerRadius
                    )
                }
            }
            .padding(.horizontal, NightflixLayout.screenPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueWatchingSubtitle(_ item: ContinueWatchingItem) -> String? {
        if item.type == .tv, let season = item.season, let episode = item.episode {
            return "S\(season):E\(episode)"
        }
        return item.type.displayName
    }

    private func messageRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NightFlixStyle.subtleFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { searchViewModel.query },
            set: { newValue in
                playErrorMessage = nil
                if searchViewModel.hasActiveQuery && newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HapticManager.shared.lightImpact()
                }
                searchViewModel.updateQuery(newValue)
            }
        )
    }

    private var feedErrorSignature: String {
        [
            viewModel.trending.errorMessage,
            viewModel.popularMovies.errorMessage,
            viewModel.popularSeries.errorMessage,
            viewModel.topRatedMovies.errorMessage,
            viewModel.topRatedSeries.errorMessage
        ]
        .compactMap { $0 }
        .joined(separator: "|")
    }

    private var contentAnimationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private func shouldShowSearchShortcut(topSafeArea: CGFloat) -> Bool {
        showContent && scrollOffset > searchShortcutThreshold(topSafeArea: topSafeArea)
    }

    private func searchShortcutThreshold(topSafeArea: CGFloat) -> CGFloat {
        HomeStickyHeaderView.scrollContentTopPadding(topSafeArea: topSafeArea) - (topSafeArea + HomeStickyHeaderView.contentHeight)
            + 58
    }

    private func updateScrollOffset(_ newOffset: CGFloat) {
        let clampedOffset = max(newOffset, 0)
        guard abs(scrollOffset - clampedOffset) > 0.5 else { return }
        scrollOffset = clampedOffset
    }

    private func requestSearchBarScroll() {
        searchShortcutRequest += 1
    }

    private func requestHomeReset() {
        homeResetRequest += 1
    }

    private func scrollToSearchBar(with proxy: ScrollViewProxy) {
        HapticManager.shared.selection()

        guard contentAnimationsEnabled else {
            proxy.scrollTo(homeTopAnchorId, anchor: .top)
            focusSearchBar(after: .milliseconds(50))
            return
        }

        withAnimation(.easeInOut(duration: 0.34)) {
            proxy.scrollTo(homeTopAnchorId, anchor: .top)
        }
        focusSearchBar(after: .milliseconds(360))
    }

    private func resetToInitialHomeScreen(with proxy: ScrollViewProxy) {
        playErrorMessage = nil
        selectedItem = nil
        selectedSeries = nil
        selectedDetailItem = nil
        selectedHomeMenuDestination = nil
        searchViewModel.clearSearch()

        guard contentAnimationsEnabled else {
            proxy.scrollTo(homeTopAnchorId, anchor: .top)
            return
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            proxy.scrollTo(homeTopAnchorId, anchor: .top)
        }
    }

    private func focusSearchBar(after delay: Duration) {
        Task {
            try? await Task.sleep(for: delay)
            searchFocusRequest += 1
        }
    }

    private func prepareStartupContentAnimation() {
        guard !hasHandledStartupContentAnimation else {
            keepContentVisible()
            return
        }

        guard contentAnimationsEnabled else {
            hasHandledStartupContentAnimation = true
            keepContentVisible()
            return
        }

        guard startupContentAnimationReady else {
            return
        }

        hasHandledStartupContentAnimation = true
        replayHomeContentAnimation()
    }

    private func replayHomeContentAnimationIfNeeded() {
        guard settings.animationMode == .total, contentAnimationsEnabled else {
            keepContentVisible()
            return
        }

        replayHomeContentAnimation()
    }

    private func keepContentVisible() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showContent = true
        }
    }

    private func replayHomeContentAnimation() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard contentAnimationsEnabled else {
                keepContentVisible()
                return
            }

            withAnimation(.easeOut(duration: 0.55)) {
                showContent = true
            }
        }
    }

    /// Stable, session-scoped key so a section title's fade-in plays only once:
    /// after the first time, scrolling it out of the lazy stack and back keeps it
    /// shown instead of replaying the animation. Titles are unique across the feed.
    private func sectionTitleOnceKey(_ title: String) -> String {
        "feed-section-title-\(title)"
    }

    /// Stable, session-scoped key so a card's fade-in plays only once: after the
    /// first time, scrolling its row out of the lazy stacks (vertically or
    /// horizontally) and back keeps it shown instead of replaying. Scoped by the
    /// row's coordinate space so the same title appearing in two rows still
    /// animates in each.
    private func cardOnceKey(_ coordinateSpaceName: String, _ itemId: String) -> String {
        "feed-card-\(coordinateSpaceName)-\(itemId)"
    }

    private func cardDelay(_ index: Int, baseDelay: Double) -> Double {
        baseDelay + min(Double(index) * 0.055, 0.44)
    }

    private func blockDelay(_ index: Int, baseDelay: Double) -> Double {
        baseDelay + min(Double(index) * 0.05, 0.3)
    }

    /// One row in the interleaved middle of the feed: either a personalized rail or a
    /// standard category rail.
    private enum FeedBlock: Identifiable {
        case personalized(PersonalizedRow)
        case category(title: String, section: FeedSection)

        var id: String {
            switch self {
            case .personalized(let row):
                return "personalized-\(row.id)"
            case .category(let title, _):
                return "category-\(title)"
            }
        }
    }

    /// Alternates the available "Because you watched" rows with the standard category
    /// rails (personalized first), then appends whatever is left over once one side
    /// runs out — so the two are mixed instead of clustered.
    private var interleavedFeedBlocks: [FeedBlock] {
        let personalized = viewModel.personalizedRows.map(FeedBlock.personalized)
        let categories: [FeedBlock] = [
            .category(title: "Popular Movies", section: viewModel.popularMovies),
            .category(title: "Popular Series", section: viewModel.popularSeries),
            .category(title: "Top Rated Movies", section: viewModel.topRatedMovies),
            .category(title: "Top Rated Series", section: viewModel.topRatedSeries)
        ]

        var blocks: [FeedBlock] = []
        var personalizedIndex = 0
        var categoryIndex = 0
        var takePersonalized = true

        while personalizedIndex < personalized.count || categoryIndex < categories.count {
            if takePersonalized, personalizedIndex < personalized.count {
                blocks.append(personalized[personalizedIndex])
                personalizedIndex += 1
            } else if categoryIndex < categories.count {
                blocks.append(categories[categoryIndex])
                categoryIndex += 1
            } else {
                blocks.append(personalized[personalizedIndex])
                personalizedIndex += 1
            }

            takePersonalized.toggle()
        }

        return blocks
    }

    private func showHeroDetail(_ item: MediaItem) {
        HapticManager.shared.lightImpact()
        selectedDetailItem = item
    }

    private func toggleHeroMyList(_ item: MediaItem) {
        guard let listItem = MyListItem(mediaItem: item) else { return }
        if myListManager.contains(mediaType: listItem.mediaType, tmdbId: listItem.tmdbId) {
            HapticManager.shared.toggleOff()
        } else {
            HapticManager.shared.bloom()
        }
        myListManager.toggle(listItem)
    }

    private func playHeroItem(_ item: MediaItem) {
        playErrorMessage = nil

        switch item.type {
        case .movie:
            guard let url = StreamingProviderURLBuilder.movieURL(
                tmdbId: item.id,
                progressSeconds: continueWatchingManager.resumeSeconds(
                    type: .movie,
                    tmdbId: String(item.id),
                    season: nil,
                    episode: nil
                )
            ) else {
                playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
                HapticManager.shared.error()
                return
            }

            HapticManager.shared.mediumImpact()
            let watchItem = WatchItem(
                type: .movie,
                title: item.displayTitle,
                tmdbId: String(item.id),
                posterPath: item.posterPath,
                generatedURL: url
            )
            historyManager.add(watchItem)
            continueWatchingManager.addOrUpdate(
                item: ContinueWatchingItem(
                    type: .movie,
                    title: item.displayTitle,
                    tmdbId: String(item.id),
                    posterPath: item.posterPath,
                    playableURL: url
                )
            )
            selectedItem = watchItem

        case .tv:
            HapticManager.shared.lightImpact()
            selectedDetailItem = item
        }
    }

    private func playContinueWatching(_ item: ContinueWatchingItem) {
        playErrorMessage = nil

        switch item.type {
        case .movie:
            guard let tmdbId = item.tmdbIntId,
                  let url = StreamingProviderURLBuilder.movieURL(
                    tmdbId: tmdbId,
                    progressSeconds: continueWatchingManager.resumeSeconds(
                        type: .movie,
                        tmdbId: item.tmdbId,
                        season: nil,
                        episode: nil
                    )
                  ) else {
                playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
                HapticManager.shared.error()
                return
            }

            let watchItem = WatchItem(
                type: .movie,
                title: item.title,
                tmdbId: item.tmdbId,
                posterPath: item.posterPath,
                generatedURL: url
            )
            historyManager.add(watchItem)
            selectedItem = watchItem

        case .tv:
            guard let tmdbId = item.tmdbIntId else {
                playErrorMessage = "The series details could not be opened."
                HapticManager.shared.error()
                return
            }

            if let season = item.season, let episode = item.episode {
                guard let url = StreamingProviderURLBuilder.tvURL(
                    tmdbId: tmdbId,
                    season: season,
                    episode: episode,
                    progressSeconds: continueWatchingManager.resumeSeconds(
                        type: .tv,
                        tmdbId: item.tmdbId,
                        season: season,
                        episode: episode
                    )
                ) else {
                    playErrorMessage = StreamingProviderURLBuilder.configurationErrorMessage
                    HapticManager.shared.error()
                    return
                }

                let watchItem = WatchItem(
                    type: .tv,
                    title: item.title,
                    tmdbId: item.tmdbId,
                    season: season,
                    episode: episode,
                    episodeName: item.episodeName,
                    posterPath: item.posterPath,
                    generatedURL: url
                )
                historyManager.add(watchItem)
                selectedItem = watchItem
                return
            }

            selectedSeries = SeriesSelection(
                id: tmdbId,
                name: item.title,
                posterPath: item.posterPath
            )
        }
    }

    private func showDetail(_ result: MediaSearchResult) {
        HapticManager.shared.mediumImpact()
        selectedDetailItem = result.mediaItem
    }
}

private struct HomeScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    @ViewBuilder
    func trackHomeScrollOffset(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newOffset in
                onChange(newOffset)
            }
        } else {
            self
        }
    }
}

#Preview {
    FeedView(
        historyManager: WatchHistoryManager(),
        continueWatchingManager: ContinueWatchingManager(),
        myListManager: MyListManager(),
        animationTrigger: 0,
        homeResetTrigger: 0,
        showNightflixTitle: true,
        shouldAnimateNightflixTitle: false,
        startupContentAnimationReady: true,
        selectedHomeMenuDestination: .constant(nil),
        onOpenHomeMenu: { }
    )
}
