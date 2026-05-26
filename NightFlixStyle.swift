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

final class AppSettingsManager: ObservableObject {
    @AppStorage("appAppearance") var appearanceRawValue: String = AppAppearance.auto.rawValue
    @AppStorage("appAnimationMode") var animationModeRawValue: String = AppAnimationMode.total.rawValue

    var appearance: AppAppearance {
        get {
            AppAppearance(rawValue: appearanceRawValue) ?? .auto
        }
        set {
            objectWillChange.send()
            appearanceRawValue = newValue.rawValue
        }
    }

    var animationMode: AppAnimationMode {
        get {
            AppAnimationMode(rawValue: animationModeRawValue) ?? .total
        }
        set {
            objectWillChange.send()
            animationModeRawValue = newValue.rawValue
        }
    }

    var preferredColorScheme: ColorScheme? {
        appearance.colorScheme
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
}

enum NightFlixStyle {
    static let accentColor = Color(hex: "e50914")
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
    static let titleGlowColor = Color.dynamic(light: .clear, dark: UIColor(red: 229 / 255, green: 9 / 255, blue: 20 / 255, alpha: 0.95))
    static let titleSecondaryGlowColor = Color.dynamic(light: .clear, dark: UIColor(red: 229 / 255, green: 9 / 255, blue: 20 / 255, alpha: 0.55))

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

enum VidkingURLBuilder {
    static func movieURL(tmdbId: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.vidking.net"
        components.path = "/embed/movie/\(tmdbId)"
        components.queryItems = fixedPlaybackQueryItems
        return components.url
    }

    static func tvURL(tmdbId: Int, season: Int, episode: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.vidking.net"
        components.path = "/embed/tv/\(tmdbId)/\(season)/\(episode)"
        components.queryItems = fixedPlaybackQueryItems
        return components.url
    }

    private static var fixedPlaybackQueryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "color", value: "e50914"),
            URLQueryItem(name: "autoPlay", value: "true"),
            URLQueryItem(name: "nextEpisode", value: "true"),
            URLQueryItem(name: "episodeSelector", value: "true")
        ]
    }
}

extension View {
    func nightflixEntrance(
        isVisible: Bool,
        delay: Double = 0,
        yOffset: CGFloat = 18,
        scaleAmount: CGFloat = 0.96,
        reduceMotionDuration: Double = 0.12,
        animationsEnabled: Bool = true
    ) -> some View {
        modifier(
            AnimatedEntranceModifier(
                isVisible: isVisible,
                delay: delay,
                yOffset: yOffset,
                scaleAmount: scaleAmount,
                reduceMotionDuration: reduceMotionDuration,
                animationsEnabled: animationsEnabled
            )
        )
    }

    func nightflixTitleGlow(opacity: CGFloat = 1) -> some View {
        modifier(NightflixTitleGlowModifier(opacity: opacity))
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

struct AnimatedEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isVisible: Bool
    let delay: Double
    let yOffset: CGFloat
    let scaleAmount: CGFloat
    let reduceMotionDuration: Double
    let animationsEnabled: Bool

    @State private var animatedVisible = false

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

    private func updateVisibility(_ visible: Bool) {
        guard animationsEnabled, !reduceMotion else {
            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                animatedVisible = true
            }
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

        withAnimation(.easeOut(duration: 0.46).delay(delay)) {
            animatedVisible = true
        }
    }
}

private struct NightflixTitleGlowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let opacity: CGFloat

    func body(content: Content) -> some View {
        content
            .background(alignment: .center) {
                Circle()
                    .fill(NightFlixStyle.accentColor)
                    .frame(width: 190, height: 72)
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
