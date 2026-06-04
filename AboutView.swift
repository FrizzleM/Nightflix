import Foundation
import Darwin
import SwiftUI

struct AboutView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    let animationTrigger: Int
    let showNightflixTitle: Bool
    let shouldAnimateNightflixTitle: Bool

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entranceVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightFlixStyle.backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        VStack(spacing: 12) {
                            externalLink(title: "GitHub", systemImage: "chevron.left.forwardslash.chevron.right", url: "https://github.com/FrizzleM")
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.29, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                            externalLink(title: "YouTube", systemImage: "play.rectangle.fill", url: "https://www.youtube.com/@frizzleofficial")
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.35, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                            externalLink(title: "Ko-fi", systemImage: "cup.and.saucer.fill", url: "https://ko-fi.com/frizzlem")
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.41, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                            externalLink(title: "Join my Discord", systemImage: "bubble.left.and.bubble.right.fill", url: "https://discord.gg/sjBcHXhS4")
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.47, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                            settingsLink
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.53, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                        }
                        .padding(.horizontal, 20)

                        appVersionFooter
                            .nightflixEntrance(isVisible: entranceVisible, delay: 0.59, yOffset: 8, animationsEnabled: aboutAnimationsEnabled)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 108)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            replayEntranceAnimationIfNeeded()
        }
        .onChange(of: animationTrigger) { _, _ in
            replayEntranceAnimationIfNeeded()
        }
        .onChange(of: reduceMotion) { _, _ in
            keepContentVisible()
        }
        .onChange(of: settings.animationMode) { _, _ in
            keepContentVisible()
        }
        .tint(NightFlixStyle.accentColor)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            NightflixTitleView(
                showTitle: showNightflixTitle,
                shouldAnimate: shouldAnimateNightflixTitle
            )

            Text("by Frizzle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.74))
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.1, yOffset: 12, scaleAmount: 0.98, animationsEnabled: aboutAnimationsEnabled)
        }
        .padding(.horizontal, 20)
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

        if let version, !version.isEmpty {
            return "Version \(version)"
        }

        return "Version Unavailable"
    }

    private var appVersionFooter: some View {
        Text(appVersionText)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.52, light: .secondaryLabel))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
    }

    private var aboutAnimationsEnabled: Bool {
        settings.animationMode == .total && !reduceMotion
    }

    private func replayEntranceAnimationIfNeeded() {
        guard aboutAnimationsEnabled else {
            keepContentVisible()
            return
        }

        replayEntranceAnimation()
    }

    private func keepContentVisible() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            entranceVisible = true
        }
    }

    private func replayEntranceAnimation() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            entranceVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard aboutAnimationsEnabled else {
                keepContentVisible()
                return
            }

            withAnimation(.easeOut(duration: 0.55)) {
                entranceVisible = true
            }
        }
    }

    private func externalLink(title: String, systemImage: String, url: String) -> some View {
        Button {
            guard let destination = URL(string: url) else {
                HapticManager.shared.error()
                return
            }

            HapticManager.shared.lightImpact()
            openURL(destination)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(NightFlixStyle.accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(NightFlixStyle.primaryTextColor)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.45, light: .tertiaryLabel))
            }
            .padding(16)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NightFlixStyle.borderColor(darkOpacity: 0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsLink: some View {
        NavigationLink {
            SettingsView(
                historyManager: historyManager,
                continueWatchingManager: continueWatchingManager
            )
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NightFlixStyle.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: "gearshape.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(NightFlixStyle.accentColor)
                }

                Text("Settings")
                    .font(.title3.weight(.black))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(NightFlixStyle.accentColor, in: Circle())
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 76)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NightFlixStyle.accentColor.opacity(0.82), lineWidth: 1.5)
            }
            .shadow(color: NightFlixStyle.accentColor.opacity(0.12), radius: 12, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticManager.shared.lightImpact()
            }
        )
    }
}

struct SettingsView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager

    @EnvironmentObject private var settings: AppSettingsManager
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var isShowingDeleteHistoryConfirmation = false
    @State private var isShowingDeleteCacheConfirmation = false
    @State private var isShowingDeleteKeysConfirmation = false
    @State private var cacheSizeBytes = 0

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    connectionSection
                    appearanceSection
                    animationsSection
                    updatesSection

                    VStack(spacing: 12) {
                        deleteHistoryButton
                        deleteCacheButton
                        deleteKeysButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear {
            refreshCacheSize()
        }
        .alert("Delete watch history?", isPresented: $isShowingDeleteHistoryConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete History", role: .destructive) {
                deleteHistory()
            }
        } message: {
            Text("This will remove Continue Watching and saved watch history from this device.")
        }
        .alert("Delete cache?", isPresented: $isShowingDeleteCacheConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Cache", role: .destructive) {
                deleteCache()
            }
        } message: {
            Text("This will remove cached TMDB data from this device. It will be downloaded again when needed.")
        }
        .alert("Delete keys?", isPresented: $isShowingDeleteKeysConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Keys", role: .destructive) {
                deleteKeys()
            }
        } message: {
            Text("This will remove your TMDB Read Access Token and movie provider from this device. Nightflix will ask for setup again when reopened.")
        }
        .tint(NightFlixStyle.accentColor)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Appearance")
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)

            Picker("Appearance", selection: appearanceBinding) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.rawValue).tag(appearance)
                }
            }
            .pickerStyle(.segmented)

            Divider()
                .background(NightFlixStyle.borderColor)

            Toggle("Haptic Feedback", isOn: hapticsBinding)
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .tint(NightFlixStyle.accentColor)
        }
        .padding(16)
        .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NightFlixStyle.borderColor, lineWidth: 1)
        }
    }

    private var connectionSection: some View {
        NavigationLink {
            ConnectionSettingsView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NightFlixStyle.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: "key.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(NightFlixStyle.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TMDB and Player")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(NightFlixStyle.primaryTextColor)

                    Text("Edit your Read Access Token and movie provider")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.secondaryTextColor)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline.weight(.black))
                    .foregroundStyle(NightFlixStyle.accentColor)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NightFlixStyle.borderColor, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticManager.shared.lightImpact()
            }
        )
    }

    private var animationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Animations")
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)

            Picker("Animations", selection: animationModeBinding) {
                ForEach(AppAnimationMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Skip intro animation", isOn: skipIntroAnimationBinding)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .tint(NightFlixStyle.accentColor)
        }
        .padding(16)
        .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NightFlixStyle.borderColor, lineWidth: 1)
        }
    }

    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Updates")
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)

            Toggle("Disable automatic update checks", isOn: disableAutomaticUpdateChecksBinding)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .tint(NightFlixStyle.accentColor)
        }
        .padding(16)
        .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NightFlixStyle.borderColor, lineWidth: 1)
        }
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { settings.appearance },
            set: { newValue in
                guard settings.appearance != newValue else { return }
                HapticManager.shared.selection()
                settings.appearance = newValue
            }
        )
    }

    private var animationModeBinding: Binding<AppAnimationMode> {
        Binding(
            get: { settings.animationMode },
            set: { newValue in
                guard settings.animationMode != newValue else { return }
                HapticManager.shared.selection()
                settings.animationMode = newValue
            }
        )
    }

    private var skipIntroAnimationBinding: Binding<Bool> {
        Binding(
            get: { settings.skipIntroAnimation },
            set: { newValue in
                guard settings.skipIntroAnimation != newValue else { return }
                HapticManager.shared.selection()
                settings.skipIntroAnimation = newValue
            }
        )
    }

    private var disableAutomaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { settings.disableAutomaticUpdateChecks },
            set: { newValue in
                guard settings.disableAutomaticUpdateChecks != newValue else { return }
                HapticManager.shared.selection()
                settings.disableAutomaticUpdateChecks = newValue
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { hapticsEnabled },
            set: { newValue in
                if !newValue {
                    HapticManager.shared.selection()
                }

                hapticsEnabled = newValue

                if newValue {
                    HapticManager.shared.selection()
                }
            }
        )
    }

    private var deleteHistoryButton: some View {
        Button(role: .destructive) {
            guard !settings.isShutdownInProgress else { return }
            HapticManager.shared.warning()
            isShowingDeleteHistoryConfirmation = true
        } label: {
            settingsOutlineButtonLabel(
                title: "Delete History",
                systemImage: "trash.fill",
                accessibilityHint: "Deletes Continue Watching and saved watch history from this device."
            )
        }
        .buttonStyle(.plain)
        .controlSize(.large)
        .disabled(settings.isShutdownInProgress)
    }

    private var deleteCacheButton: some View {
        Button(role: .destructive) {
            guard !settings.isShutdownInProgress else { return }
            HapticManager.shared.warning()
            isShowingDeleteCacheConfirmation = true
        } label: {
            settingsOutlineButtonLabel(
                title: "Delete Cache (\(cacheSizeText))",
                systemImage: "trash.fill",
                accessibilityHint: "Deletes cached TMDB data from this device."
            )
        }
        .buttonStyle(.plain)
        .controlSize(.large)
        .disabled(settings.isShutdownInProgress)
    }

    private var deleteKeysButton: some View {
        Button(role: .destructive) {
            guard !settings.isShutdownInProgress else { return }
            HapticManager.shared.warning()
            isShowingDeleteKeysConfirmation = true
        } label: {
            settingsOutlineButtonLabel(
                title: "Delete Keys",
                systemImage: "trash.fill",
                accessibilityHint: "Deletes setup keys from this device and asks for setup again."
            )
        }
        .buttonStyle(.plain)
        .controlSize(.large)
        .disabled(settings.isShutdownInProgress)
    }

    private func deleteHistory() {
        historyManager.clear()
        continueWatchingManager.clear()
        HapticManager.shared.success()
        terminateApp()
    }

    private func deleteCache() {
        Task {
            await TMDBService.clearCache()
            let cacheSizeBytes = await TMDBService.cacheSizeBytes()

            await MainActor.run {
                self.cacheSizeBytes = cacheSizeBytes
                HapticManager.shared.success()
                terminateApp()
            }
        }
    }

    private func deleteKeys() {
        HapticManager.shared.success()
        terminateApp {
            settings.resetInitialSetupCredentials()
        }
    }

    private func terminateApp(afterPreparingForShutdown prepareForShutdown: () -> Void = {}) {
        guard settings.beginShutdownCountdown() else { return }
        prepareForShutdown()
        UserDefaults.standard.synchronize()

        Task { @MainActor in
            for secondsRemaining in stride(from: 2, through: 1, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                settings.updateShutdownCountdown(to: secondsRemaining)
            }

            try? await Task.sleep(for: .seconds(1))
            exit(0)
        }
    }

    private var cacheSizeText: String {
        guard cacheSizeBytes > 0 else { return "0 MB" }

        let megabytes = Double(cacheSizeBytes) / 1_048_576
        guard megabytes >= 0.1 else { return "<0.1 MB" }

        return "\(String(format: "%.1f", megabytes)) MB"
    }

    private func refreshCacheSize() {
        Task {
            let cacheSizeBytes = await TMDBService.cacheSizeBytes()

            await MainActor.run {
                self.cacheSizeBytes = cacheSizeBytes
            }
        }
    }
}

struct ShutdownCountdownOverlay: View {
    let secondsRemaining: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 14) {
                powerIcon

                Text("Nightflix will close")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)

                Text("\(secondsRemaining)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: NightFlixStyle.accentColor.opacity(0.35), radius: 18)

                Text("Reopen the app from your Home Screen.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
            .padding(26)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.48),
                                .white.opacity(0.16),
                                NightFlixStyle.accentColor.opacity(0.26)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.24), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(height: 120)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.35), radius: 28, y: 18)
            .padding(24)
        }
    }

    private var powerIcon: some View {
        ZStack {
            Circle()
                .fill(NightFlixStyle.accentColor.opacity(0.22))
                .frame(width: 86, height: 86)
                .blur(radius: 22)

            Image(systemName: "power")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(NightFlixStyle.accentColor)
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.10), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

private struct ConnectionSettingsView: View {
    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.openURL) private var openURL

    @State private var tmdbCredentialDraft = ""
    @State private var providerBaseURLDraft = ""
    @State private var statusMessage: String?
    @State private var isStatusError = false
    @State private var statusDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    credentialSection

                    if let statusMessage {
                        Label(
                            statusMessage,
                            systemImage: isStatusError ? "exclamationmark.circle.fill" : "checkmark.circle.fill"
                        )
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(isStatusError ? NightFlixStyle.accentColor : NightFlixStyle.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        saveConnectionSettings()
                    } label: {
                        settingsOutlineButtonLabel(
                            title: "Save Setup Details",
                            systemImage: "checkmark",
                            accessibilityHint: "Saves your TMDB Read Access Token and movie provider."
                        )
                    }
                    .buttonStyle(.plain)
                    .controlSize(.large)
                    .disabled(!canSaveConnectionSettings)
                    .opacity(canSaveConnectionSettings ? 1 : 0.45)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("TMDB and Player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(NightFlixStyle.accentColor)
        .onAppear {
            syncConnectionDrafts()
        }
        .onDisappear {
            statusDismissTask?.cancel()
        }
    }

    private var credentialSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("TMDB Read Access Token")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.secondaryTextColor)

                SecureField("Read Access Token", text: $tmdbCredentialDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .nightFlixInputFieldStyle()

                Button {
                    openTMDBAPIPage()
                } label: {
                    Label("Create a TMDB account", systemImage: "arrow.up.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(NightFlixStyle.accentColor)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Movie Provider URL")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.secondaryTextColor)

                TextField("https://example.com", text: $providerBaseURLDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .nightFlixInputFieldStyle()
            }
        }
        .padding(16)
        .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NightFlixStyle.borderColor, lineWidth: 1)
        }
    }

    private var canSaveConnectionSettings: Bool {
        NightFlixUserConfiguration.isValidTMDBReadAccessToken(tmdbCredentialDraft)
    }

    private func syncConnectionDrafts() {
        tmdbCredentialDraft = settings.tmdbCredential
        providerBaseURLDraft = settings.streamingProviderBaseURL
    }

    private func saveConnectionSettings() {
        let normalizedTMDBCredential = NightFlixUserConfiguration.normalizedTMDBCredential(from: tmdbCredentialDraft)

        guard NightFlixUserConfiguration.isValidTMDBReadAccessToken(normalizedTMDBCredential) else {
            showTemporaryStatus("Add a TMDB Read Access Token before saving.", isError: true)
            HapticManager.shared.error()
            return
        }

        let normalizedProviderURL = NightFlixUserConfiguration.normalizedStreamingProviderBaseURL(from: providerBaseURLDraft)
        settings.tmdbCredential = normalizedTMDBCredential
        settings.streamingProviderBaseURL = normalizedProviderURL

        tmdbCredentialDraft = normalizedTMDBCredential
        providerBaseURLDraft = normalizedProviderURL
        showTemporaryStatus(
            normalizedProviderURL.isEmpty
                ? "TMDB saved. Add a movie provider when you're ready to play."
                : "Setup details saved.",
            isError: false
        )
        HapticManager.shared.success()
    }

    private func showTemporaryStatus(_ message: String, isError: Bool) {
        statusDismissTask?.cancel()
        isStatusError = isError

        withAnimation(.easeIn(duration: 0.18)) {
            statusMessage = message
        }

        statusDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(isError ? 2.4 : 1.8))
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.28)) {
                statusMessage = nil
            }
        }
    }

    private func openTMDBAPIPage() {
        guard let url = URL(string: "https://www.themoviedb.org/signup") else { return }
        HapticManager.shared.lightImpact()
        openURL(url)
    }
}

private func settingsOutlineButtonLabel(
    title: String,
    systemImage: String,
    accessibilityHint: String
) -> some View {
    HStack(spacing: 10) {
        Image(systemName: systemImage)
            .font(.headline.weight(.bold))

        Text(title)
            .font(.headline.weight(.bold))
    }
    .foregroundStyle(NightFlixStyle.accentColor)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 15)
    .padding(.horizontal, 18)
    .background(NightFlixStyle.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(NightFlixStyle.accentColor.opacity(0.78), lineWidth: 1)
    }
    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .hoverEffect(.highlight)
    .accessibilityHint(accessibilityHint)
}

#Preview {
    AboutView(
        historyManager: WatchHistoryManager(),
        continueWatchingManager: ContinueWatchingManager(),
        animationTrigger: 0,
        showNightflixTitle: true,
        shouldAnimateNightflixTitle: false
    )
    .environmentObject(AppSettingsManager())
}
