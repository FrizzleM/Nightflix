import Foundation
import SwiftUI

struct AboutView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    let animationTrigger: Int
    let showNightflixTitle: Bool
    let shouldAnimateNightflixTitle: Bool
    let onHistoryDeleted: () -> Void

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
                            settingsLink
                                .nightflixEntrance(isVisible: entranceVisible, delay: 0.47, yOffset: 12, animationsEnabled: aboutAnimationsEnabled)
                        }
                        .padding(.horizontal, 20)

                        appVersionFooter
                            .nightflixEntrance(isVisible: entranceVisible, delay: 0.53, yOffset: 8, animationsEnabled: aboutAnimationsEnabled)
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
                continueWatchingManager: continueWatchingManager,
                onHistoryDeleted: onHistoryDeleted
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

private struct SettingsView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    let onHistoryDeleted: () -> Void

    @EnvironmentObject private var settings: AppSettingsManager
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var isShowingDeleteHistoryConfirmation = false
    @State private var isShowingDeleteCacheConfirmation = false
    @State private var cacheSizeBytes = 0

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    appearanceSection
                    animationsSection

                    VStack(spacing: 12) {
                        deleteHistoryButton
                        deleteCacheButton
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
            HapticManager.shared.warning()
            isShowingDeleteHistoryConfirmation = true
        } label: {
            destructiveButtonLabel(
                title: "Delete History",
                accessibilityHint: "Deletes Continue Watching and saved watch history from this device."
            )
        }
        .buttonStyle(.plain)
        .controlSize(.large)
    }

    private var deleteCacheButton: some View {
        Button(role: .destructive) {
            HapticManager.shared.warning()
            isShowingDeleteCacheConfirmation = true
        } label: {
            destructiveButtonLabel(
                title: "Delete Cache (\(cacheSizeText))",
                accessibilityHint: "Deletes cached TMDB data from this device."
            )
        }
        .buttonStyle(.plain)
        .controlSize(.large)
    }

    private func destructiveButtonLabel(title: String, accessibilityHint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trash.fill")
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

    private func deleteHistory() {
        historyManager.clear()
        continueWatchingManager.clear()
        HapticManager.shared.success()
        onHistoryDeleted()
    }

    private func deleteCache() {
        Task {
            await TMDBService.clearCache()
            let cacheSizeBytes = await TMDBService.cacheSizeBytes()

            await MainActor.run {
                self.cacheSizeBytes = cacheSizeBytes
                HapticManager.shared.success()
            }
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

#Preview {
    AboutView(
        historyManager: WatchHistoryManager(),
        continueWatchingManager: ContinueWatchingManager(),
        animationTrigger: 0,
        showNightflixTitle: true,
        shouldAnimateNightflixTitle: false,
        onHistoryDeleted: { }
    )
        .environmentObject(AppSettingsManager())
}
