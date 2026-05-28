import SwiftUI

struct FeedView: View {
    private let homeScrollCoordinateSpace = "home-feed-scroll"
    private let homeTopAnchorId = "home-top-anchor"
    private let homeSearchAnchorId = "home-search-anchor"

    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    @ObservedObject var myListManager: MyListManager
    let animationTrigger: Int
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

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    NightFlixStyle.backgroundColor.ignoresSafeArea()

                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            scrollOffsetReader
                                .id(homeTopAnchorId)

                            LazyVStack(alignment: .leading, spacing: 24) {
                                feedSearchBar
                                    .id(homeSearchAnchorId)

                                if let playErrorMessage {
                                    messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
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
                                } else {
                                    featuredHeroSection(baseDelay: 0.42)
                                    continueWatchingSection(baseDelay: 0.5)
                                    feedSection(title: "Trending This Week", section: viewModel.trending, baseDelay: 0.54)
                                    feedSection(title: "Popular Movies", section: viewModel.popularMovies, baseDelay: 0.6)
                                    feedSection(title: "Popular Series", section: viewModel.popularSeries, baseDelay: 0.66)
                                    feedSection(title: "Top Rated Movies", section: viewModel.topRatedMovies, baseDelay: 0.72)
                                    feedSection(title: "Top Rated Series", section: viewModel.topRatedSeries, baseDelay: 0.78)
                                }
                            }
                            .padding(.horizontal, 20)
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
                            if feedErrorSignature.isEmpty {
                                HapticManager.shared.success()
                            } else {
                                HapticManager.shared.error()
                            }
                        }
                        .onChange(of: searchShortcutRequest) { _, _ in
                            scrollToSearchBar(with: scrollProxy)
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
                        onSearchShortcut: requestSearchBarScroll,
                        onOpenMenu: onOpenHomeMenu
                    )
                    .zIndex(100)
                    .ignoresSafeArea(edges: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedItem) { item in
                PlayerView(item: item)
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
                .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 14, scaleAmount: 0.97, animationsEnabled: contentAnimationsEnabled)
        } else if let item = viewModel.featuredHeroItem {
            HeroBannerView(
                item: item,
                onPrimaryAction: showHeroDetail,
                onMoreInfo: showHeroDetail
            )
            .frame(maxWidth: .infinity)
            .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 14, scaleAmount: 0.97, animationsEnabled: contentAnimationsEnabled)
        }
    }

    @ViewBuilder
    private func continueWatchingSection(baseDelay: Double) -> some View {
        if !continueWatchingManager.items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderView(title: "Continue Watching")
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(continueWatchingManager.items.enumerated()), id: \.element.id) { index, item in
                            continueWatchingCard(item)
                                .scrollHapticCard(index: index, coordinateSpaceName: "continue-watching-row")
                                .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .horizontalScrollHaptics(coordinateSpaceName: "continue-watching-row", isEnabled: showContent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func feedSection(title: String, section: FeedSection, baseDelay: Double) -> some View {
        let coordinateSpaceName = "feed-row-\(title)"

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title)
            .nightflixEntrance(isVisible: showContent, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)

            if let errorMessage = section.errorMessage {
                messageRow(errorMessage, systemImage: "info.circle.fill")
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, animationsEnabled: contentAnimationsEnabled)
            } else if section.isLoading && section.items.isEmpty {
                loadingRow
                    .nightflixEntrance(isVisible: showContent, delay: baseDelay + 0.05, yOffset: 12, scaleAmount: 0.98, animationsEnabled: contentAnimationsEnabled)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(section.items.enumerated()), id: \.element) { index, item in
                            feedCard(item)
                                .scrollHapticCard(index: index, coordinateSpaceName: coordinateSpaceName)
                                .nightflixEntrance(isVisible: showContent, delay: cardDelay(index, baseDelay: baseDelay + 0.06), yOffset: 12, animationsEnabled: contentAnimationsEnabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .horizontalScrollHaptics(coordinateSpaceName: coordinateSpaceName, isEnabled: showContent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(0..<6, id: \.self) { _ in
                    CardSkeletonView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func continueWatchingCard(_ item: ContinueWatchingItem) -> some View {
        Button {
            HapticManager.shared.mediumImpact()
            playContinueWatching(item)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                NightFlixPosterImage(url: item.posterURL, width: 132, height: 198)

                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)

                Text(item.type.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.78))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(NightFlixStyle.fillColor(darkOpacity: 0.08), in: Capsule())
                    .frame(height: 22, alignment: .leading)

                Label("Continue", systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(.white)
                    .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(10)
            .frame(width: 152, alignment: .top)
            .contentShape(Rectangle())
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NightFlixStyle.borderColor(darkOpacity: 0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continue \(item.title)")
    }

    private func feedCard(_ item: FeedItem) -> some View {
        Button {
            HapticManager.shared.mediumImpact()
            selectedDetailItem = item.mediaItem
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                NightFlixPosterImage(url: item.posterURL, width: 132, height: 198)

                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(2)
                    .frame(height: 38, alignment: .topLeading)

                HStack(spacing: 6) {
                    Text(item.year ?? "Year N/A")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.58))
                        .lineLimit(1)

                    Text(item.type.displayName)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.78))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(NightFlixStyle.fillColor(darkOpacity: 0.08), in: Capsule())
                }
                .frame(height: 22, alignment: .leading)

                feedCardActionLabel(for: item)
            }
            .padding(10)
            .frame(width: 152, alignment: .top)
            .contentShape(Rectangle())
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NightFlixStyle.borderColor(darkOpacity: 0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feedCardAccessibilityLabel(for: item))
    }

    private func feedCardActionLabel(for item: FeedItem) -> some View {
        Label("Play", systemImage: "play.fill")
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(.white)
            .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func feedCardAccessibilityLabel(for item: FeedItem) -> String {
        "Play \(item.title)"
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

    private func cardDelay(_ index: Int, baseDelay: Double) -> Double {
        baseDelay + min(Double(index) * 0.055, 0.44)
    }

    private func showHeroDetail(_ item: MediaItem) {
        HapticManager.shared.lightImpact()
        selectedDetailItem = item
    }

    private func playContinueWatching(_ item: ContinueWatchingItem) {
        playErrorMessage = nil

        if let playableURL = item.playableURL {
            let watchItem = WatchItem(
                type: item.type,
                title: item.title,
                tmdbId: item.tmdbId,
                posterPath: item.posterPath,
                generatedURL: playableURL
            )
            historyManager.add(watchItem)
            selectedItem = watchItem
            return
        }

        switch item.type {
        case .movie:
            guard let tmdbId = item.tmdbIntId,
                  let url = VidkingURLBuilder.movieURL(tmdbId: tmdbId) else {
                playErrorMessage = "The movie player URL could not be created."
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
        showNightflixTitle: true,
        shouldAnimateNightflixTitle: false,
        startupContentAnimationReady: true,
        selectedHomeMenuDestination: .constant(nil),
        onOpenHomeMenu: { }
    )
}
