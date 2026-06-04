import SwiftUI

struct MainTabView: View {
    private enum AppTab {
        case home
        case about
    }

    let playsStartupIntro: Bool

    @State private var historyManager = WatchHistoryManager()
    @State private var continueWatchingManager = ContinueWatchingManager()
    @State private var selectedTab: AppTab = .home
    @State private var homeAnimationTrigger = 0
    @State private var homeResetTrigger = 0
    @State private var aboutAnimationTrigger = 0
    @State private var hasPlayedNightflixTitleStartupAnimation = false
    @State private var showNightflixTitle = false
    @State private var homeStartupContentAnimationReady = false
    @State private var hasStartedStartupAnimation = false
    @State private var isShowingStartupAnimation = true
    @State private var hasStartedUpdateCheck = false
    @State private var canShowUpdatePrompt = false
    @State private var hasScheduledUpdatePromptUnlock = false
    @State private var availableUpdate: NightflixAppUpdate?
    @State private var isShowingUpdatePrompt = false
    @State private var selectedHomeMenuDestination: HomeMenuDestination?
    @State private var isShowingHomeMenu = false
    @StateObject private var myListManager = MyListManager()

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    init(playsStartupIntro: Bool = true) {
        self.playsStartupIntro = playsStartupIntro
    }

    var body: some View {
        ZStack {
            TabView(selection: selectedTabBinding) {
                FeedView(
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager,
                    myListManager: myListManager,
                    animationTrigger: homeAnimationTrigger,
                    homeResetTrigger: homeResetTrigger,
                    showNightflixTitle: showNightflixTitle,
                    shouldAnimateNightflixTitle: shouldAnimateNightflixTitle,
                    startupContentAnimationReady: homeStartupContentAnimationReady,
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
                    shouldAnimateNightflixTitle: shouldAnimateNightflixTitle
                )
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(AppTab.about)
            }
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
                onSettings: {
                    selectHomeMenuDestination(.settings)
                },
                onDonate: {
                    openDonate()
                },
                onDiscord: {
                    openDiscord()
                },
                onDismiss: {
                    dismissHomeMenu()
                }
            )
            .zIndex(999)

            if isShowingUpdatePrompt, let availableUpdate {
                NightflixUpdatePromptView(
                    update: availableUpdate,
                    onUpdate: {
                        openUpdate(availableUpdate)
                    },
                    onDismiss: {
                        dismissUpdatePrompt()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1002)
            }

            if isShowingStartupAnimation && shouldShowStartupIntro {
                NightflixStartupAnimationView(animationsEnabled: startupAnimationsEnabled) {
                    finishStartupAnimation()
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            HapticManager.shared.selection()
            replayEntranceAnimation(for: newValue)
        }
        .onAppear {
            startStartupAnimationIfNeeded()
        }
        .task {
            await checkForUpdatesIfNeeded()
        }
        .onChange(of: reduceMotion) { _, _ in
            finishStartupAnimationIfDisabled()
            resolveNightflixTitleVisibilityForCurrentSettings()
        }
        .onChange(of: settings.animationMode) { _, _ in
            finishStartupAnimationIfDisabled()
            resolveNightflixTitleVisibilityForCurrentSettings()
        }
        .onChange(of: settings.skipIntroAnimation) { _, _ in
            finishStartupAnimationIfDisabled()
        }
    }

    private var shouldAnimateNightflixTitle: Bool {
        !hasPlayedNightflixTitleStartupAnimation && settings.animationMode != .off && !reduceMotion
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .home {
                    homeResetTrigger += 1
                }

                selectedTab = newTab
            }
        )
    }

    private var startupAnimationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private var shouldShowStartupIntro: Bool {
        playsStartupIntro && startupAnimationsEnabled && !settings.skipIntroAnimation
    }

    private func startStartupAnimationIfNeeded() {
        guard !hasStartedStartupAnimation else { return }

        hasStartedStartupAnimation = true

        guard shouldShowStartupIntro else {
            finishStartupAnimation()
            return
        }

        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showNightflixTitle = false
            isShowingStartupAnimation = true
        }
    }

    private func finishStartupAnimationIfDisabled() {
        guard isShowingStartupAnimation, !shouldShowStartupIntro else { return }
        finishStartupAnimation()
    }

    private func finishStartupAnimation() {
        guard isShowingStartupAnimation else { return }

        let animation: Animation? = startupAnimationsEnabled ? .easeOut(duration: 0.28) : nil

        withAnimation(animation) {
            isShowingStartupAnimation = false
        }

        playNightflixTitleStartupAnimationIfNeeded()
    }

    private func playNightflixTitleStartupAnimationIfNeeded() {
        guard shouldAnimateNightflixTitle else {
            showNightflixTitleImmediately(markAsPlayed: true)
            unlockUpdatePromptAfterStartup()
            return
        }

        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            showNightflixTitle = false
            homeStartupContentAnimationReady = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard shouldAnimateNightflixTitle else {
                showNightflixTitleImmediately(markAsPlayed: true)
                unlockUpdatePromptAfterStartup()
                return
            }

            withAnimation(.easeOut(duration: 0.6)) {
                showNightflixTitle = true
            }

            homeStartupContentAnimationReady = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                hasPlayedNightflixTitleStartupAnimation = true
                unlockUpdatePromptAfterStartup()
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
            homeStartupContentAnimationReady = true
        }

        if markAsPlayed {
            hasPlayedNightflixTitleStartupAnimation = true
        }
    }

    private func checkForUpdatesIfNeeded() async {
        guard !hasStartedUpdateCheck else { return }
        hasStartedUpdateCheck = true
        settings.updateAutomaticUpdateCheckPreferenceForInstalledVersion()

        guard settings.automaticUpdateChecksEnabled else {
            return
        }

        do {
            guard let update = try await NightflixUpdateChecker.availableUpdate() else {
                return
            }

            availableUpdate = update
            presentUpdatePromptIfReady()
        } catch {
            return
        }
    }

    private func unlockUpdatePromptAfterStartup() {
        guard !hasScheduledUpdatePromptUnlock else { return }
        hasScheduledUpdatePromptUnlock = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            canShowUpdatePrompt = true
            presentUpdatePromptIfReady()
        }
    }

    private func presentUpdatePromptIfReady() {
        guard canShowUpdatePrompt, availableUpdate != nil, !isShowingUpdatePrompt else {
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

    private func openDiscord() {
        HapticManager.shared.lightImpact()
        setHomeMenuVisible(false)

        guard let url = URL(string: "https://discord.gg/sjBcHXhS4") else {
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

struct NightflixStartupAnimationView: View {
    let animationsEnabled: Bool
    let onFinished: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasStarted = false
    @State private var wordmarkOpacity = 1.0
    @State private var sloganOpacity = 0.0

    var body: some View {
        ZStack {
            introBackgroundColor
                .ignoresSafeArea()

            Text("Nightflix")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NightFlixStyle.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .opacity(wordmarkOpacity)
                .padding(.horizontal, 32)

            slogan
                .opacity(sloganOpacity)
                .offset(y: 54)
                .padding(.horizontal, 32)
        }
        .accessibilityHidden(true)
        .task {
            await runAnimationIfNeeded()
        }
        .onChange(of: animationsEnabled) { _, enabled in
            if !enabled {
                onFinished()
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                onFinished()
            }
        }
    }

    private var slogan: some View {
        HStack(spacing: 0) {
            Text("an app by ")
                .foregroundStyle(sloganPrefixColor)

            Text("Frizzle")
                .foregroundStyle(frizzleBlue)
                .nightflixSloganGlow(color: frizzleBlue)
        }
        .font(.system(size: 24, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private var frizzleBlue: Color {
        Color(hex: "2F80FF")
    }

    private var introBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var sloganPrefixColor: Color {
        colorScheme == .dark ? .white.opacity(0.76) : .black.opacity(0.72)
    }

    @MainActor
    private func runAnimationIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        withAnimation(.easeInOut(duration: 0.7)) {
            sloganOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(1_250))

        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        withAnimation(.easeInOut(duration: 0.95)) {
            wordmarkOpacity = 0
            sloganOpacity = 0
        }

        try? await Task.sleep(for: .milliseconds(980))

        onFinished()
    }
}

private extension View {
    func nightflixSloganGlow(color: Color) -> some View {
        modifier(NightflixSloganGlowModifier(color: color))
    }
}

private struct NightflixSloganGlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let color: Color

    func body(content: Content) -> some View {
        content
            .background(alignment: .center) {
                Circle()
                    .fill(color)
                    .frame(width: 92, height: 34)
                    .opacity(glowOpacity)
                    .blur(radius: 18)
                    .allowsHitTesting(false)
            }
            .shadow(color: color.opacity(primaryShadowOpacity), radius: 12)
            .shadow(color: color.opacity(secondaryShadowOpacity), radius: 24)
    }

    private var glowOpacity: Double {
        colorScheme == .dark ? 0.18 : 0.08
    }

    private var primaryShadowOpacity: Double {
        colorScheme == .dark ? 0.82 : 0.34
    }

    private var secondaryShadowOpacity: Double {
        colorScheme == .dark ? 0.48 : 0.16
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSettingsManager())
}
