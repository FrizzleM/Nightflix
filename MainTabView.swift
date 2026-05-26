import SwiftUI

struct MainTabView: View {
    private enum AppTab {
        case home
        case about
    }

    @State private var historyManager = WatchHistoryManager()
    @State private var continueWatchingManager = ContinueWatchingManager()
    @State private var appSessionId = UUID()
    @State private var selectedTab: AppTab = .home
    @State private var homeAnimationTrigger = 0
    @State private var aboutAnimationTrigger = 0
    @State private var hasPlayedNightflixTitleStartupAnimation = false
    @State private var showNightflixTitle = false
    @State private var selectedHomeMenuDestination: HomeMenuDestination?
    @State private var isShowingHomeMenu = false
    @StateObject private var myListManager = MyListManager()

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FeedView(
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager,
                    myListManager: myListManager,
                    animationTrigger: homeAnimationTrigger,
                    showNightflixTitle: showNightflixTitle,
                    shouldAnimateNightflixTitle: shouldAnimateNightflixTitle,
                    selectedHomeMenuDestination: $selectedHomeMenuDestination,
                    onOpenHomeMenu: openHomeMenu
                )
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(AppTab.home)

                AboutView(
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager,
                    animationTrigger: aboutAnimationTrigger,
                    showNightflixTitle: showNightflixTitle,
                    shouldAnimateNightflixTitle: shouldAnimateNightflixTitle,
                    onHistoryDeleted: restartAppState
                )
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(AppTab.about)
            }
            .id(appSessionId)
            .tint(NightFlixStyle.accentColor)

            HomeMenuSheet(
                isPresented: isShowingHomeMenu,
                animationsEnabled: homeMenuAnimationsEnabled,
                onMyList: {
                    selectHomeMenuDestination(.myList)
                },
                onCategories: {
                    selectHomeMenuDestination(.categories)
                },
                onDonate: {
                    openDonate()
                },
                onDismiss: {
                    dismissHomeMenu()
                }
            )
            .zIndex(999)
        }
        .onChange(of: selectedTab) { _, newValue in
            HapticManager.shared.selection()
            replayEntranceAnimation(for: newValue)
        }
        .onAppear {
            playNightflixTitleStartupAnimationIfNeeded()
        }
        .onChange(of: reduceMotion) { _, _ in
            resolveNightflixTitleVisibilityForCurrentSettings()
        }
        .onChange(of: settings.animationMode) { _, _ in
            resolveNightflixTitleVisibilityForCurrentSettings()
        }
    }

    private func restartAppState() {
        historyManager = WatchHistoryManager()
        continueWatchingManager = ContinueWatchingManager()
        appSessionId = UUID()
    }

    private var shouldAnimateNightflixTitle: Bool {
        !hasPlayedNightflixTitleStartupAnimation && settings.animationMode != .off && !reduceMotion
    }

    private func playNightflixTitleStartupAnimationIfNeeded() {
        guard shouldAnimateNightflixTitle else {
            showNightflixTitleImmediately(markAsPlayed: true)
            return
        }

        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showNightflixTitle = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard shouldAnimateNightflixTitle else {
                showNightflixTitleImmediately(markAsPlayed: true)
                return
            }

            withAnimation(.easeOut(duration: 0.6)) {
                showNightflixTitle = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                hasPlayedNightflixTitleStartupAnimation = true
            }
        }
    }

    private func resolveNightflixTitleVisibilityForCurrentSettings() {
        if settings.animationMode == .off || reduceMotion {
            showNightflixTitleImmediately(markAsPlayed: true)
            return
        }

        if hasPlayedNightflixTitleStartupAnimation {
            showNightflixTitleImmediately(markAsPlayed: false)
        }
    }

    private func showNightflixTitleImmediately(markAsPlayed: Bool) {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showNightflixTitle = true
        }

        if markAsPlayed {
            hasPlayedNightflixTitleStartupAnimation = true
        }
    }

    private func replayEntranceAnimation(for tab: AppTab) {
        guard settings.animationMode == .total else { return }

        switch tab {
        case .home:
            homeAnimationTrigger += 1
        case .about:
            aboutAnimationTrigger += 1
        }
    }

    private var homeMenuAnimationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private var homeMenuNavigationDelay: Double {
        homeMenuAnimationsEnabled ? 0.18 : 0
    }

    private var homeMenuAnimation: Animation {
        settings.animationMode == .total
            ? .interactiveSpring(response: 0.32, dampingFraction: 0.86)
            : .easeOut(duration: 0.22)
    }

    private func openHomeMenu() {
        HapticManager.shared.lightImpact()
        setHomeMenuVisible(true)
    }

    private func dismissHomeMenu() {
        HapticManager.shared.lightImpact()
        setHomeMenuVisible(false)
    }

    private func selectHomeMenuDestination(_ destination: HomeMenuDestination) {
        HapticManager.shared.lightImpact()
        setHomeMenuVisible(false)

        DispatchQueue.main.asyncAfter(deadline: .now() + homeMenuNavigationDelay) {
            selectedHomeMenuDestination = destination
        }
    }

    private func openDonate() {
        HapticManager.shared.lightImpact()
        setHomeMenuVisible(false)

        guard let url = URL(string: "https://ko-fi.com/frizzlem") else {
            HapticManager.shared.error()
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + homeMenuNavigationDelay) {
            openURL(url)
        }
    }

    private func setHomeMenuVisible(_ isVisible: Bool) {
        guard homeMenuAnimationsEnabled else {
            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                isShowingHomeMenu = isVisible
            }
            return
        }

        withAnimation(homeMenuAnimation) {
            isShowingHomeMenu = isVisible
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSettingsManager())
}
