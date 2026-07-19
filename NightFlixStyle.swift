import SwiftUI
import UIKit
import Combine

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case auto = "Auto"
    case dark = "Dark"
    case light = "Light"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}

enum AppAnimationMode: String, CaseIterable, Identifiable, Codable {
    case total = "Full"
    case partial = "Startup Only"
    case off = "Off"

    var id: String { rawValue }
}

enum AppSettingsStorageKey {
    static let appAppearance = "appAppearance"
    static let appAnimationMode = "appAnimationMode"
    static let skipIntroAnimation = "skipIntroAnimation"
    static let disableAutomaticUpdateChecks = "disableAutomaticUpdateChecks"
    static let lastInstalledVersionCode = "lastInstalledVersionCode"
    static let hasCompletedInitialSetup = "hasCompletedInitialSetup"
    static let tmdbCredential = "tmdbCredential"
    static let streamingProviderBaseURL = "streamingProviderBaseURL"
    static let accentColorHex = "accentColorHex"
}

enum NightFlixUserConfiguration {
    /// Credentials are baked in — the app requires no setup or user input.
    static let defaultTMDBCredential = "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI3MTNlY2VkZmQ1NmVkNDZiMDBiZTg1N2Q3ODg3NTE1MSIsIm5iZiI6MTc3OTYyMzA4Mi4xNzUsInN1YiI6IjZhMTJlNGFhOWFkOWYxOWE3ZWE5Y2NiZiIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.8g0u3KwAVxnWszrKGfqvxrUl0VuG-_e0ZvTv5xDVRd4"
    static let defaultStreamingProviderBaseURL = "player.videasy.net"
    /// The original Nightflix red, used when no custom accent has been chosen.
    static let defaultAccentColorHex = "e50914"

    /// The effective TMDB token: a user-saved override if valid, otherwise the baked-in default.
    static var effectiveTMDBCredential: String {
        let stored = normalizedTMDBCredential(
            from: UserDefaults.standard.string(forKey: AppSettingsStorageKey.tmdbCredential) ?? ""
        )
        return isValidTMDBReadAccessToken(stored) ? stored : normalizedTMDBCredential(from: defaultTMDBCredential)
    }

    /// The effective provider URL: a user-saved override if present, otherwise the baked-in default.
    static var effectiveStreamingProviderBaseURL: String {
        let stored = normalizedStreamingProviderBaseURL(
            from: UserDefaults.standard.string(forKey: AppSettingsStorageKey.streamingProviderBaseURL) ?? ""
        )
        return stored.isEmpty ? normalizedStreamingProviderBaseURL(from: defaultStreamingProviderBaseURL) : stored
    }

    /// The effective accent colour as a 6-digit hex string (no `#`): the user's chosen
    /// colour when set and valid, otherwise the default Nightflix red.
    static var effectiveAccentColorHex: String {
        let stored = normalizedAccentColorHex(
            from: UserDefaults.standard.string(forKey: AppSettingsStorageKey.accentColorHex) ?? ""
        )
        return stored.isEmpty ? defaultAccentColorHex : stored
    }

    /// Normalises an accent colour input to a bare lowercase 6-digit hex string, or "" when invalid.
    static func normalizedAccentColorHex(from rawValue: String) -> String {
        let trimmed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()

        guard trimmed.count == 6, trimmed.allSatisfy(\.isHexDigit) else { return "" }
        return trimmed
    }

    static func normalizedTMDBCredential(from rawValue: String) -> String {
        var trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedValue.hasCaseInsensitivePrefix("Bearer ") {
            trimmedValue = String(trimmedValue.dropFirst("Bearer ".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return trimmedValue
    }

    static func isValidTMDBReadAccessToken(_ rawValue: String) -> Bool {
        normalizedTMDBCredential(from: rawValue)
            .split(separator: ".")
            .count == 3
    }

    static func normalizedStreamingProviderBaseURL(from rawValue: String) -> String {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return "" }

        let valueWithScheme: String
        if trimmedValue.hasCaseInsensitivePrefix("http://") {
            valueWithScheme = "https://\(trimmedValue.dropFirst("http://".count))"
        } else if trimmedValue.range(of: "://") == nil {
            valueWithScheme = "https://\(trimmedValue)"
        } else {
            valueWithScheme = trimmedValue
        }

        return valueWithScheme.trimmingTrailingSlashes()
    }
}

final class AppSettingsManager: ObservableObject {
    @AppStorage(AppSettingsStorageKey.appAppearance) var appearanceRawValue: String = AppAppearance.auto.rawValue
    @AppStorage(AppSettingsStorageKey.disableAutomaticUpdateChecks) private var disableAutomaticUpdateChecksStorage = false
    @AppStorage(AppSettingsStorageKey.lastInstalledVersionCode) private var lastInstalledVersionCodeStorage = 0
    @AppStorage(AppSettingsStorageKey.hasCompletedInitialSetup) private var hasCompletedInitialSetupStorage = false
    @AppStorage(AppSettingsStorageKey.tmdbCredential) private var tmdbCredentialStorage = ""
    @AppStorage(AppSettingsStorageKey.streamingProviderBaseURL) private var streamingProviderBaseURLStorage = ""
    @AppStorage(AppSettingsStorageKey.accentColorHex) private var accentColorHexStorage = ""
    @Published private(set) var shutdownCountdown: Int?

    var appearance: AppAppearance {
        get {
            AppAppearance(rawValue: appearanceRawValue) ?? .auto
        }
        set {
            objectWillChange.send()
            appearanceRawValue = newValue.rawValue
        }
    }

    /// Animations are always on at full strength — this is the standard now and is
    /// no longer user-configurable.
    var animationMode: AppAnimationMode { .total }

    /// The intro animation always plays, in keeping with full standard animations.
    var skipIntroAnimation: Bool { false }

    var automaticUpdateChecksEnabled: Bool {
        get {
            !disableAutomaticUpdateChecksStorage
        }
        set {
            objectWillChange.send()
            disableAutomaticUpdateChecksStorage = !newValue
        }
    }

    var hasCompletedInitialSetup: Bool {
        get {
            hasCompletedInitialSetupStorage
        }
        set {
            objectWillChange.send()
            hasCompletedInitialSetupStorage = newValue
        }
    }

    var tmdbCredential: String {
        get {
            NightFlixUserConfiguration.effectiveTMDBCredential
        }
        set {
            objectWillChange.send()
            tmdbCredentialStorage = NightFlixUserConfiguration.normalizedTMDBCredential(from: newValue)
        }
    }

    /// True when a valid user-supplied TMDB token is overriding the baked-in default.
    var isUsingCustomTMDBCredential: Bool {
        !customTMDBCredentialOverride.isEmpty
    }

    /// The raw user-saved TMDB token override, or "" when the default is in use.
    /// (Unlike `tmdbCredential`, this never falls back to the baked-in token.)
    var customTMDBCredentialOverride: String {
        let stored = NightFlixUserConfiguration.normalizedTMDBCredential(from: tmdbCredentialStorage)
        return NightFlixUserConfiguration.isValidTMDBReadAccessToken(stored) ? stored : ""
    }

    /// Drops any custom token so the app reverts to the baked-in default key.
    func resetTMDBCredential() {
        guard !tmdbCredentialStorage.isEmpty else { return }
        objectWillChange.send()
        tmdbCredentialStorage = ""
    }

    var streamingProviderBaseURL: String {
        get {
            NightFlixUserConfiguration.effectiveStreamingProviderBaseURL
        }
        set {
            objectWillChange.send()
            streamingProviderBaseURLStorage = NightFlixUserConfiguration.normalizedStreamingProviderBaseURL(from: newValue)
        }
    }

    /// The chosen accent colour as a bare hex string (no `#`).
    var accentColorHex: String {
        get {
            NightFlixUserConfiguration.effectiveAccentColorHex
        }
        set {
            let normalized = NightFlixUserConfiguration.normalizedAccentColorHex(from: newValue)
            guard !normalized.isEmpty, normalized != accentColorHexStorage else { return }
            objectWillChange.send()
            accentColorHexStorage = normalized
        }
    }

    /// The chosen accent colour as a SwiftUI `Color`.
    var accentColor: Color {
        Color(hex: accentColorHex)
    }

    func resetAccentColor() {
        guard !accentColorHexStorage.isEmpty else { return }
        objectWillChange.send()
        accentColorHexStorage = ""
    }

    var hasConfiguredTMDBCredential: Bool {
        NightFlixUserConfiguration.isValidTMDBReadAccessToken(tmdbCredential)
    }

    var hasConfiguredStreamingProvider: Bool {
        !streamingProviderBaseURL.isEmpty
    }

    var preferredColorScheme: ColorScheme? {
        appearance.colorScheme
    }

    var isShutdownInProgress: Bool {
        shutdownCountdown != nil
    }

    func completeInitialSetup(tmdbCredential: String, streamingProviderBaseURL: String) {
        objectWillChange.send()
        tmdbCredentialStorage = NightFlixUserConfiguration.normalizedTMDBCredential(from: tmdbCredential)
        streamingProviderBaseURLStorage = NightFlixUserConfiguration.normalizedStreamingProviderBaseURL(from: streamingProviderBaseURL)
        hasCompletedInitialSetupStorage = true
    }

    func resetInitialSetupCredentials() {
        UserDefaults.standard.removeObject(forKey: AppSettingsStorageKey.tmdbCredential)
        UserDefaults.standard.removeObject(forKey: AppSettingsStorageKey.streamingProviderBaseURL)
        UserDefaults.standard.set(false, forKey: AppSettingsStorageKey.hasCompletedInitialSetup)
    }

    func beginShutdownCountdown() -> Bool {
        guard shutdownCountdown == nil else { return false }
        shutdownCountdown = 3
        return true
    }

    func updateShutdownCountdown(to secondsRemaining: Int) {
        shutdownCountdown = secondsRemaining
    }

    func updateAutomaticUpdateCheckPreferenceForInstalledVersion() {
        guard let currentVersionCode = NightflixUpdateChecker.currentInstalledVersionCode else {
            return
        }

        guard lastInstalledVersionCodeStorage > 0 else {
            lastInstalledVersionCodeStorage = currentVersionCode
            return
        }

        guard currentVersionCode != lastInstalledVersionCodeStorage else {
            return
        }

        objectWillChange.send()

        if currentVersionCode > lastInstalledVersionCodeStorage {
            disableAutomaticUpdateChecksStorage = false
        }

        lastInstalledVersionCodeStorage = currentVersionCode
    }
}

extension Color {
    init(hex: String) {
        let sanitizedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitizedHex).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xff) / 255
        let green = Double((value >> 8) & 0xff) / 255
        let blue = Double(value & 0xff) / 255

        self.init(red: red, green: green, blue: blue)
    }

    /// A bare lowercase 6-digit hex string (no `#`) for the colour's RGB components.
    var nightflixHexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let clamp = { (component: CGFloat) -> Int in min(max(Int((component * 255).rounded()), 0), 255) }
        return String(format: "%02x%02x%02x", clamp(red), clamp(green), clamp(blue))
    }
}

/// A named accent colour the user can pick from in Settings.
struct NightflixAccentOption: Identifiable, Hashable {
    let name: String
    let hex: String

    var id: String { hex }
    var color: Color { Color(hex: hex) }
}

enum NightflixAccentPalette {
    /// The curated presets, with the default Nightflix red first.
    static let presets: [NightflixAccentOption] = [
        NightflixAccentOption(name: "Nightflix Red", hex: NightFlixUserConfiguration.defaultAccentColorHex),
        NightflixAccentOption(name: "Sunset", hex: "ff6a00"),
        NightflixAccentOption(name: "Gold", hex: "f5c518"),
        NightflixAccentOption(name: "Emerald", hex: "1db954"),
        NightflixAccentOption(name: "Teal", hex: "00b8d4"),
        NightflixAccentOption(name: "Azure", hex: "2f80ff"),
        NightflixAccentOption(name: "Violet", hex: "9146ff"),
        NightflixAccentOption(name: "Magenta", hex: "ff2d92")
    ]

    static func isPreset(_ hex: String) -> Bool {
        presets.contains { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }
    }
}

/// SwiftUI environment carrier for the accent colour. Reusable leaf views (badges,
/// progress bars) read this instead of the `NightFlixStyle.accentColor` static so they
/// re-render the instant the user changes the colour, rather than staying cached.
private struct NightflixAccentEnvironmentKey: EnvironmentKey {
    static var defaultValue: Color { NightFlixStyle.accentColor }
}

extension EnvironmentValues {
    var nightflixAccent: Color {
        get { self[NightflixAccentEnvironmentKey.self] }
        set { self[NightflixAccentEnvironmentKey.self] = newValue }
    }
}

enum NightFlixStyle {
    /// The app-wide accent. Resolves to the user's chosen colour (or the default red),
    /// so every call site updates automatically when the setting changes.
    static var accentColor: Color {
        Color(hex: NightFlixUserConfiguration.effectiveAccentColorHex)
    }

    /// The accent as a `UIColor`, for building dynamic (light/dark) derivatives.
    static var accentUIColor: UIColor {
        UIColor(accentColor)
    }
    static let backgroundColor = Color.dynamic(light: .systemBackground, dark: .black)
    static let cardColor = Color.dynamic(light: .secondarySystemBackground, dark: UIColor(red: 27 / 255, green: 27 / 255, blue: 31 / 255, alpha: 1))
    static let fieldColor = Color.dynamic(light: .tertiarySystemBackground, dark: .black.withAlphaComponent(0.35))
    static let primaryTextColor = Color.dynamic(light: .label, dark: .white)
    static let secondaryTextColor = Color.dynamic(light: .secondaryLabel, dark: .white.withAlphaComponent(0.68))
    static let tertiaryTextColor = Color.dynamic(light: .tertiaryLabel, dark: .white.withAlphaComponent(0.52))
    static let mutedTextColor = Color.dynamic(light: .tertiaryLabel, dark: .white.withAlphaComponent(0.45))
    static let borderColor = Color.dynamic(light: .separator.withAlphaComponent(0.35), dark: .white.withAlphaComponent(0.07))
    static let prominentBorderColor = Color.dynamic(light: .separator.withAlphaComponent(0.45), dark: .white.withAlphaComponent(0.09))
    static let subtleFillColor = Color.dynamic(light: .systemGray5, dark: .white.withAlphaComponent(0.06))
    /// The glow behind the Nightflix wordmark — follows the accent colour (dark mode only).
    static var titleGlowColor: Color {
        Color.dynamic(light: .clear, dark: accentUIColor.withAlphaComponent(0.95))
    }
    static var titleSecondaryGlowColor: Color {
        Color.dynamic(light: .clear, dark: accentUIColor.withAlphaComponent(0.55))
    }

    static func textColor(darkOpacity: CGFloat, light: UIColor = .secondaryLabel) -> Color {
        Color.dynamic(light: light, dark: .white.withAlphaComponent(darkOpacity))
    }

    static func fillColor(darkOpacity: CGFloat, light: UIColor = .systemGray5) -> Color {
        Color.dynamic(light: light, dark: .white.withAlphaComponent(darkOpacity))
    }

    static func borderColor(darkOpacity: CGFloat) -> Color {
        Color.dynamic(light: .separator.withAlphaComponent(0.35), dark: .white.withAlphaComponent(darkOpacity))
    }
}

struct NightflixTitleView: View {
    let showTitle: Bool
    let shouldAnimate: Bool

    var body: some View {
        Text("Nightflix")
            .font(.system(size: 38, weight: .bold, design: .rounded))
            .foregroundStyle(NightFlixStyle.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .nightflixTitleGlow()
            .shadow(color: NightFlixStyle.titleGlowColor, radius: 16)
            .shadow(color: NightFlixStyle.titleSecondaryGlowColor, radius: 34)
            .nightflixEntrance(
                isVisible: showTitle,
                delay: 0.1,
                yOffset: 14,
                scaleAmount: 0.98,
                reduceMotionDuration: 0,
                animationsEnabled: shouldAnimate
            )
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum StreamingProviderURLBuilder {
    static var isConfigured: Bool {
        !providerBaseURL.isEmpty
    }

    static let configurationErrorMessage = "Add a movie provider URL in Settings before playing."

    static func movieURL(tmdbId: Int, progressSeconds: Int? = nil) -> URL? {
        url(appending: "/movie/\(tmdbId)", isSeries: false, progressSeconds: progressSeconds)
    }

    static func tvURL(tmdbId: Int, season: Int, episode: Int, progressSeconds: Int? = nil) -> URL? {
        url(appending: "/tv/\(tmdbId)/\(season)/\(episode)", isSeries: true, progressSeconds: progressSeconds)
    }

    private static var providerBaseURL: String {
        NightFlixUserConfiguration.effectiveStreamingProviderBaseURL
    }

    private static func url(appending embedPath: String, isSeries: Bool, progressSeconds: Int?) -> URL? {
        guard !providerBaseURL.isEmpty,
              var components = URLComponents(string: providerBaseURL),
              components.scheme != nil,
              components.host != nil else {
            return nil
        }

        let basePath = components.path.trimmingSlashes()
        let routePath = embedPath.trimmingSlashes()
        let combinedPath = [basePath, routePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.path = "/\(combinedPath)"

        // Videasy's `progress` query param sets the resume start time (seconds). Some
        // embed players re-apply that seek on every playback tick, which snaps the
        // video back and makes it loop on the resume second. We keep the param (it's
        // what actually resumes) and suppress any such repeats in the WebView — see
        // `WebView.resumeLoopGuardScript`.
        var queryItems = (components.queryItems ?? []) + playbackQueryItems(isSeries: isSeries)
        if let progressSeconds, progressSeconds > 0 {
            queryItems.append(URLQueryItem(name: "progress", value: String(progressSeconds)))
        }
        components.queryItems = queryItems

        return components.url
    }

    /// Videasy player parameters (see the Videasy embed docs). `color` themes the
    /// player to the app accent (hex, no `#`) and `overlay` enables the Netflix-style
    /// paused overlay; the episode-navigation params only apply to TV series.
    private static func playbackQueryItems(isSeries: Bool) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "color", value: NightFlixUserConfiguration.effectiveAccentColorHex),
            URLQueryItem(name: "overlay", value: "true")
        ]

        if isSeries {
            items.append(contentsOf: [
                URLQueryItem(name: "nextEpisode", value: "true"),
                URLQueryItem(name: "episodeSelector", value: "true"),
                URLQueryItem(name: "autoplayNextEpisode", value: "true")
            ])
        }

        return items
    }
}

private extension String {
    func hasCaseInsensitivePrefix(_ prefix: String) -> Bool {
        range(of: prefix, options: [.caseInsensitive, .anchored]) != nil
    }

    func trimmingTrailingSlashes() -> String {
        var value = self

        while value.hasSuffix("/") {
            value.removeLast()
        }

        return value
    }

    func trimmingSlashes() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

extension View {
    func nightflixEntrance(
        isVisible: Bool,
        delay: Double = 0,
        yOffset: CGFloat = 18,
        scaleAmount: CGFloat = 0.96,
        reduceMotionDuration: Double = 0.12,
        animationsEnabled: Bool = true,
        onceKey: String? = nil
    ) -> some View {
        modifier(
            AnimatedEntranceModifier(
                isVisible: isVisible,
                delay: delay,
                yOffset: yOffset,
                scaleAmount: scaleAmount,
                reduceMotionDuration: reduceMotionDuration,
                animationsEnabled: animationsEnabled,
                onceKey: onceKey
            )
        )
    }

    func nightflixTitleGlow(opacity: CGFloat = 1, scale: CGFloat = 1, offset: CGSize = .zero) -> some View {
        modifier(NightflixTitleGlowModifier(opacity: opacity, scale: scale, offset: offset))
    }

    func nightFlixInputFieldStyle() -> some View {
        self
            .font(.body.weight(.semibold))
            .foregroundStyle(NightFlixStyle.primaryTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(NightFlixStyle.fieldColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NightFlixStyle.prominentBorderColor, lineWidth: 1)
            }
    }

    func nightFlixResultCardStyle() -> some View {
        self
            .padding(14)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NightFlixStyle.borderColor, lineWidth: 1)
            }
    }
}

/// Remembers, for the lifetime of the app process (i.e. one session), which keyed
/// entrance animations have already played. Used so a fade-in only happens once
/// per session: when a view is recreated — e.g. a feed section scrolling out of a
/// `LazyVStack` and back in — it can render fully shown instead of replaying.
/// The set lives only in memory, so it naturally resets when the app relaunches.
final class EntranceAnimationTracker {
    static let shared = EntranceAnimationTracker()

    private var playedKeys: Set<String> = []

    func hasPlayed(_ key: String) -> Bool {
        playedKeys.contains(key)
    }

    func markPlayed(_ key: String) {
        playedKeys.insert(key)
    }
}

struct AnimatedEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isVisible: Bool
    let delay: Double
    let yOffset: CGFloat
    let scaleAmount: CGFloat
    let reduceMotionDuration: Double
    let animationsEnabled: Bool
    /// When set, the fade-in plays only the first time it runs in a session.
    /// Later appearances (e.g. after scrolling away and back) show immediately.
    let onceKey: String?

    @State private var animatedVisible: Bool

    init(
        isVisible: Bool,
        delay: Double,
        yOffset: CGFloat,
        scaleAmount: CGFloat,
        reduceMotionDuration: Double,
        animationsEnabled: Bool,
        onceKey: String?
    ) {
        self.isVisible = isVisible
        self.delay = delay
        self.yOffset = yOffset
        self.scaleAmount = scaleAmount
        self.reduceMotionDuration = reduceMotionDuration
        self.animationsEnabled = animationsEnabled
        self.onceKey = onceKey

        // If this entrance already played earlier in the session, start fully
        // shown so the recreated view neither flashes nor replays the fade-in.
        let alreadyPlayed = onceKey.map(EntranceAnimationTracker.shared.hasPlayed) ?? false
        _animatedVisible = State(initialValue: alreadyPlayed)
    }

    func body(content: Content) -> some View {
        content
            .opacity(shouldShowImmediately || animatedVisible ? 1 : 0)
            .offset(y: offsetValue)
            .scaleEffect(scaleValue)
            .onAppear {
                updateVisibility(isVisible)
            }
            .onChange(of: isVisible) { _, newValue in
                updateVisibility(newValue)
            }
            .onChange(of: reduceMotion) { _, _ in
                updateVisibility(isVisible)
            }
            .onChange(of: animationsEnabled) { _, _ in
                updateVisibility(isVisible)
            }
    }

    private var shouldShowImmediately: Bool {
        !animationsEnabled || reduceMotion
    }

    private var offsetValue: CGFloat {
        guard !shouldShowImmediately else { return 0 }
        return animatedVisible ? 0 : yOffset
    }

    private var scaleValue: CGFloat {
        guard !shouldShowImmediately else { return 1 }
        return animatedVisible ? 1 : scaleAmount
    }

    private var hasAlreadyPlayedThisSession: Bool {
        guard let onceKey else { return false }
        return EntranceAnimationTracker.shared.hasPlayed(onceKey)
    }

    private func updateVisibility(_ visible: Bool) {
        guard animationsEnabled, !reduceMotion else {
            showImmediately()
            return
        }

        // A play-once entrance that already ran stays shown — it must not replay
        // when the view is recreated or when `isVisible` toggles during a replay.
        if hasAlreadyPlayedThisSession {
            showImmediately()
            return
        }

        guard visible else {
            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                animatedVisible = false
            }
            return
        }

        if let onceKey {
            EntranceAnimationTracker.shared.markPlayed(onceKey)
        }

        withAnimation(.easeOut(duration: 0.46).delay(delay)) {
            animatedVisible = true
        }
    }

    private func showImmediately() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            animatedVisible = true
        }
    }
}

private struct NightflixTitleGlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let opacity: CGFloat
    let scale: CGFloat
    let offset: CGSize

    func body(content: Content) -> some View {
        content
            .background(alignment: .center) {
                Circle()
                    .fill(NightFlixStyle.accentColor)
                    .frame(width: 190, height: 72)
                    .scaleEffect(scale)
                    .offset(offset)
                    .opacity(baseOpacity * opacity)
                    .blur(radius: 36)
                    .allowsHitTesting(false)
            }
    }

    private var baseOpacity: CGFloat {
        colorScheme == .dark ? 0.18 : 0.06
    }
}

private extension Color {
    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        })
    }
}

struct NightFlixPosterImage: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                PosterSkeletonView(width: width, height: height)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var placeholder: some View {
        PosterFallbackView()
    }
}
