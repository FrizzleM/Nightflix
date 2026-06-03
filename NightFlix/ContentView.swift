import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var suppressMainStartupIntroAfterSetup = false
    @State private var isShowingSetupStartupAnimation = true

    var body: some View {
        ZStack {
            if settings.isShutdownInProgress {
                NightFlixStyle.backgroundColor.ignoresSafeArea()
            } else if settings.hasCompletedInitialSetup {
                MainTabView(playsStartupIntro: !suppressMainStartupIntroAfterSetup)
            } else {
                InitialSetupView()
                    .onAppear {
                        suppressMainStartupIntroAfterSetup = true
                    }
            }

            if let shutdownCountdown = settings.shutdownCountdown {
                ShutdownCountdownOverlay(secondsRemaining: shutdownCountdown)
                    .transition(.opacity)
                    .zIndex(1001)
            }

            if shouldShowSetupStartupAnimation {
                NightflixStartupAnimationView(animationsEnabled: setupStartupAnimationsEnabled) {
                    finishSetupStartupAnimation()
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .onChange(of: settings.hasCompletedInitialSetup) { _, isComplete in
            if isComplete {
                finishSetupStartupAnimation()
            }
        }
        .onChange(of: reduceMotion) { _, _ in
            finishSetupStartupAnimationIfDisabled()
        }
        .onChange(of: settings.animationMode) { _, _ in
            finishSetupStartupAnimationIfDisabled()
        }
        .onChange(of: settings.skipIntroAnimation) { _, _ in
            finishSetupStartupAnimationIfDisabled()
        }
    }

    private var setupStartupAnimationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private var shouldShowSetupStartupAnimation: Bool {
        guard !settings.isShutdownInProgress else { return false }

        return !settings.hasCompletedInitialSetup &&
        isShowingSetupStartupAnimation &&
        setupStartupAnimationsEnabled &&
        !settings.skipIntroAnimation
    }

    private func finishSetupStartupAnimationIfDisabled() {
        guard isShowingSetupStartupAnimation,
              settings.hasCompletedInitialSetup || !setupStartupAnimationsEnabled || settings.skipIntroAnimation else {
            return
        }

        finishSetupStartupAnimation()
    }

    private func finishSetupStartupAnimation() {
        guard isShowingSetupStartupAnimation else { return }

        let animation: Animation? = setupStartupAnimationsEnabled ? .easeOut(duration: 0.28) : nil

        withAnimation(animation) {
            isShowingSetupStartupAnimation = false
        }
    }
}

private struct InitialSetupView: View {
    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.openURL) private var openURL
    @FocusState private var focusedField: SetupField?

    @State private var step: SetupStep = .tmdb
    @State private var tmdbCredentialDraft = ""
    @State private var providerBaseURLDraft = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        setupHeader

                        Spacer(minLength: 28)

                        currentPage
                            .id(step)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                            )

                        Spacer(minLength: 28)

                        progressDots
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            tmdbCredentialDraft = settings.tmdbCredential
            providerBaseURLDraft = settings.streamingProviderBaseURL
        }
    }

    private var setupHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nightflix")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(NightFlixStyle.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .nightflixTitleGlow()

            Text("Step \(step.rawValue + 1) of \(SetupStep.allCases.count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        switch step {
        case .tmdb:
            tmdbPage
        case .provider:
            providerPage
        case .done:
            donePage
        }
    }

    private var tmdbPage: some View {
        setupPage(
            systemImage: "key.fill",
            title: "Add your TMDB token",
            wikiURL: Self.tmdbKeyWikiURL
        ) {
            inputContainer {
                SecureField("TMDB Read Access Token", text: $tmdbCredentialDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .tmdb)
                    .onSubmit {
                        goToProvider()
                    }
            }

            Button {
                openTMDBAPIPage()
            } label: {
                Label("Create a TMDB account", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.accentColor)
            }
            .buttonStyle(.plain)
        } actions: {
            primaryButton(
                title: "Continue",
                systemImage: "arrow.right",
                isDisabled: !hasValidTMDBCredential,
                action: goToProvider
            )
        }
    }

    private var providerPage: some View {
        setupPage(
            systemImage: "play.rectangle.fill",
            title: "Add your provider",
            wikiURL: Self.sourcesWikiURL
        ) {
            inputContainer {
                TextField("Enter your provider", text: $providerBaseURLDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .provider)
                    .onSubmit {
                        goToDone()
                    }
            }

            Text("You can leave this blank and add it later in Settings.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.56))
        } actions: {
            VStack(spacing: 12) {
                primaryButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    isDisabled: providerBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    action: goToDone
                )

                secondaryButton(title: "Do it later", systemImage: "clock") {
                    providerBaseURLDraft = ""
                    goToDone()
                }
            }
        }
    }

    private var donePage: some View {
        setupPage(
            systemImage: "checkmark.seal.fill",
            title: "You're done",
            message: "Setup is complete. Welcome to Nightflix."
        ) {
            EmptyView()
        } actions: {
            primaryButton(
                title: "Enter Nightflix",
                systemImage: "play.fill",
                isDisabled: false,
                action: completeSetup
            )
        }
    }

    private func setupPage<Content: View, Actions: View>(
        systemImage: String,
        title: String,
        message: String? = nil,
        wikiURL: URL? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            ZStack {
                Circle()
                    .fill(NightFlixStyle.accentColor.opacity(0.16))
                    .frame(width: 68, height: 68)

                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(NightFlixStyle.accentColor)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let message {
                    Text(message)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()

            actions()
                .padding(.top, 8)

            if let wikiURL {
                wikiHelpLink(destination: wikiURL)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wikiHelpLink(destination: URL) -> some View {
        Link(destination: destination) {
            HStack(spacing: 5) {
                Text("Need help? Read the")
                    .foregroundStyle(.white.opacity(0.58))

                Text("wiki")
                    .foregroundStyle(NightFlixStyle.accentColor)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(NightFlixStyle.accentColor)
            }
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Need help? Read the wiki")
    }

    private func inputContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .textContentType(.none)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NightFlixStyle.accentColor.opacity(0.72), lineWidth: 1)
            }
    }

    private func primaryButton(
        title: String,
        systemImage: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityHint(isDisabled ? "Complete this step to continue." : "")
    }

    private func secondaryButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(SetupStep.allCases) { setupStep in
                Capsule()
                    .fill(setupStep == step ? NightFlixStyle.accentColor : .white.opacity(0.18))
                    .frame(width: setupStep == step ? 28 : 8, height: 8)
                    .animation(.easeOut(duration: 0.22), value: step)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var hasValidTMDBCredential: Bool {
        NightFlixUserConfiguration.isValidTMDBReadAccessToken(tmdbCredentialDraft)
    }

    private func goToProvider() {
        guard hasValidTMDBCredential else {
            HapticManager.shared.error()
            return
        }

        tmdbCredentialDraft = NightFlixUserConfiguration.normalizedTMDBCredential(from: tmdbCredentialDraft)
        HapticManager.shared.selection()

        withAnimation(.easeOut(duration: 0.24)) {
            step = .provider
        }

        focusedField = .provider
    }

    private func goToDone() {
        providerBaseURLDraft = NightFlixUserConfiguration.normalizedStreamingProviderBaseURL(from: providerBaseURLDraft)
        HapticManager.shared.selection()

        withAnimation(.easeOut(duration: 0.24)) {
            step = .done
        }

        focusedField = nil
    }

    private func completeSetup() {
        guard hasValidTMDBCredential else {
            HapticManager.shared.error()

            withAnimation(.easeOut(duration: 0.24)) {
                step = .tmdb
            }

            focusedField = .tmdb
            return
        }

        HapticManager.shared.success()
        settings.completeInitialSetup(
            tmdbCredential: tmdbCredentialDraft,
            streamingProviderBaseURL: providerBaseURLDraft
        )
    }

    private func openTMDBAPIPage() {
        guard let url = URL(string: "https://www.themoviedb.org/signup") else { return }
        HapticManager.shared.lightImpact()
        openURL(url)
    }

    private static let tmdbKeyWikiURL = URL(string: "https://github.com/FrizzleM/Nightflix/wiki/Setting-up-a-TMDB-key")!
    private static let sourcesWikiURL = URL(string: "https://github.com/FrizzleM/Nightflix/wiki/Sources")!
}

private enum SetupStep: Int, CaseIterable, Identifiable, Hashable {
    case tmdb
    case provider
    case done

    var id: Int { rawValue }
}

private enum SetupField: Hashable {
    case tmdb
    case provider
}

#Preview {
    ContentView()
        .environmentObject(AppSettingsManager())
}
