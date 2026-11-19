import SwiftUI

/// The app shell: Home, New & Hot and My Nightflix behind a translucent tab bar. Tabs
/// stay alive once visited (so scroll positions survive switching), tapping the
/// current tab scrolls it back to the top, and the startup intro and update prompt sit
/// above everything.
struct NFRootView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case home
        case newHot
        case my

        var id: String { rawValue }

        var title: String {
            switch self {
            case .home: return "Home"
            case .newHot: return "New & Hot"
            case .my: return "My Nightflix"
            }
        }
    }

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var app = NFAppModel()
    @StateObject private var myList = MyListManager()

    @State private var selectedTab: Tab = .home
    @State private var visitedTabs: Set<Tab> = [.home]
    @State private var scrollToTopTokens: [Tab: Int] = [:]

    @State private var isShowingStartup = true
    @State private var availableUpdate: NightflixAppUpdate?
    @State private var isShowingUpdatePrompt = false
    @State private var hasStartedUpdateCheck = false

    var body: some View {
        ZStack {
            NF.canvas.ignoresSafeArea()

            tabs
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    NFTabBar(selected: selectedTab, onSelect: select)
                }
                .nfRouterHost()

            if let picker = app.picker {
                NFPickerOverlay(request: picker) {
                    app.picker = nil
                }
                .id(picker.id)
                .zIndex(10)
            }

            if isShowingUpdatePrompt, let availableUpdate {
                NightflixUpdatePromptView(
                    update: availableUpdate,
                    onUpdate: { openUpdate(availableUpdate) },
                    onDismiss: { dismissUpdatePrompt() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(20)
            }

            if isShowingStartup && startupEnabled {
                NightflixStartupAnimationView(animationsEnabled: startupEnabled) {
                    finishStartup()
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(30)
            }
        }
        .environment(app)
        .environmentObject(myList)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .preferredColorScheme(.dark)
        .onAppear {
            if !startupEnabled {
                finishStartup()
            }
        }
        .task {
            await checkForUpdatesIfNeeded()
        }
    }

    // MARK: - Tabs

    private var tabs: some View {
        ZStack {
            ForEach(Tab.allCases) { tab in
                if visitedTabs.contains(tab) {
                    tabContent(tab)
                        .opacity(selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(selectedTab == tab)
                        .accessibilityHidden(selectedTab != tab)
                        .zIndex(selectedTab == tab ? 1 : 0)
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: Tab) -> some View {
        let token = scrollToTopTokens[tab, default: 0]

        switch tab {
        case .home:
            NFHomeView(scrollToTopToken: token)
        case .newHot:
            NFNewHotView(scrollToTopToken: token)
        case .my:
            NFMyNightflixView(scrollToTopToken: token)
        }
    }

    private func select(_ tab: Tab) {
        guard tab != selectedTab else {
            scrollToTopTokens[tab, default: 0] += 1
            return
        }

        HapticManager.shared.tabChange()
        visitedTabs.insert(tab)

        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            selectedTab = tab
        }
    }

    // MARK: - Startup / updates

    private var startupEnabled: Bool {
        settings.animationMode != .off && !reduceMotion && !settings.skipIntroAnimation
    }

    private func finishStartup() {
        guard isShowingStartup else { return }

        withAnimation(startupEnabled ? .easeOut(duration: 0.28) : nil) {
            isShowingStartup = false
        }

        presentUpdatePromptIfReady()
    }

    private func checkForUpdatesIfNeeded() async {
        guard !hasStartedUpdateCheck else { return }
        hasStartedUpdateCheck = true
        settings.updateAutomaticUpdateCheckPreferenceForInstalledVersion()

        guard settings.automaticUpdateChecksEnabled else { return }

        guard let update = try? await NightflixUpdateChecker.availableUpdate() else {
            return
        }

        availableUpdate = update
        presentUpdatePromptIfReady()
    }

    private func presentUpdatePromptIfReady() {
        guard !isShowingStartup || !startupEnabled,
              availableUpdate != nil,
              !isShowingUpdatePrompt else {
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            isShowingUpdatePrompt = true
        }
    }

    private func dismissUpdatePrompt() {
        HapticManager.shared.lightImpact()

        withAnimation(.easeOut(duration: 0.18)) {
            isShowingUpdatePrompt = false
        }

        availableUpdate = nil
    }

    private func openUpdate(_ update: NightflixAppUpdate) {
        HapticManager.shared.lightImpact()

        withAnimation(.easeOut(duration: 0.18)) {
            isShowingUpdatePrompt = false
        }

        availableUpdate = nil
        openURL(update.downloadURL)
    }
}

// MARK: - Tab bar

private struct NFTabBar: View {
    let selected: NFRootView.Tab
    let onSelect: (NFRootView.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NFRootView.Tab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        icon(for: tab)
                            .frame(height: 26)

                        Text(tab.title)
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected == tab ? Color.white : Color(white: 0.55))
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.72)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func icon(for tab: NFRootView.Tab) -> some View {
        let isSelected = selected == tab

        switch tab {
        case .home:
            Image(systemName: isSelected ? "house.fill" : "house")
                .font(.system(size: 21, weight: .regular))
        case .newHot:
            Image(systemName: isSelected ? "play.rectangle.on.rectangle.fill" : "play.rectangle.on.rectangle")
                .font(.system(size: 20, weight: .regular))
        case .my:
            NFProfileAvatar(size: 24, isSelected: isSelected)
        }
    }
}
