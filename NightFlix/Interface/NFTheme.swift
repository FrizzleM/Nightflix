import SwiftUI

/// Design tokens for the Nightflix interface: a true-black canvas, neutral greys for
/// secondary text and surfaces, white primary actions, and the user's accent colour
/// (Nightflix red by default) reserved for badges, progress and selection.
enum NF {
    // MARK: Palette

    static let canvas = Color.black
    /// Sheets and raised panels.
    static let surface = Color(white: 0.11)
    /// Fields, secondary buttons and placeholders.
    static let surfaceRaised = Color(white: 0.17)
    static let hairline = Color.white.opacity(0.1)

    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.72)
    static let textTertiary = Color(white: 0.5)
    static let textMuted = Color(white: 0.38)

    /// TMDB score tint (Netflix-style "match" green).
    static let positive = Color(red: 0.27, green: 0.83, blue: 0.47)

    // MARK: Metrics

    static let gutter: CGFloat = 16
    static let posterCorner: CGFloat = 4
    static let cardCorner: CGFloat = 6
    static let buttonCorner: CGFloat = 5

    /// Poster width for the home rails, scaled to the container.
    static func posterWidth(for containerWidth: CGFloat) -> CGFloat {
        guard containerWidth > 0 else { return 108 }
        let width = (containerWidth - gutter) / 3.35
        return min(max(width, 100), 158).rounded()
    }

    // MARK: Type

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Display face for titles without a logo: heavy and slightly condensed.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }

    // MARK: Images

    enum ImageSize {
        case poster
        case posterLarge
        case backdrop
        case backdropLarge
        case still
        case profile
        case logo

        var segment: String {
            switch self {
            case .poster: return "w342"
            case .posterLarge: return "w780"
            case .backdrop: return "w780"
            case .backdropLarge: return "w1280"
            case .still: return "w300"
            case .profile: return "w185"
            case .logo: return "w500"
            }
        }
    }

    static func imageURL(_ path: String?, _ size: ImageSize) -> URL? {
        guard let path, !path.isEmpty else { return nil }

        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute
        }

        let trimmed = path.hasPrefix("/") ? path : "/\(path)"
        return URL(string: "https://image.tmdb.org/t/p/\(size.segment)\(trimmed)")
    }

    // MARK: Genres

    /// TMDB's stable genre catalogue (movie + TV) so list responses can show names
    /// without an extra request.
    static let genreNames: [Int: String] = [
        28: "Action", 12: "Adventure", 16: "Animation", 35: "Comedy", 80: "Crime",
        99: "Documentary", 18: "Drama", 10751: "Family", 14: "Fantasy", 36: "History",
        27: "Horror", 10402: "Music", 9648: "Mystery", 10749: "Romance", 878: "Sci-Fi",
        10770: "TV Movie", 53: "Thriller", 10752: "War", 37: "Western",
        10759: "Action & Adventure", 10762: "Kids", 10763: "News", 10764: "Reality",
        10765: "Sci-Fi & Fantasy", 10766: "Soap", 10767: "Talk", 10768: "War & Politics"
    ]

    /// Genres that read like broadcast TV rather than titles you'd stream.
    static let excludedGenres: Set<Int> = [10763, 10767]

    static func genreTags(_ ids: [Int]?, limit: Int = 3) -> [String] {
        guard let ids else { return [] }

        var seen = Set<String>()
        return ids
            .compactMap { genreNames[$0] }
            .filter { seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Formatting

    static func scorePercent(_ voteAverage: Double?) -> Int? {
        guard let voteAverage, voteAverage > 0 else { return nil }
        return Int((voteAverage * 10).rounded())
    }

    static func runtimeText(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }

    static func remainingText(seconds: Double) -> String {
        "\(compactDuration(seconds: seconds)) left"
    }

    /// "1h 5m" / "45m" — for tight spaces like card footers.
    static func compactDuration(seconds: Double) -> String {
        let minutes = max(Int((seconds / 60).rounded()), 1)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(fromTMDB value: String?) -> Date? {
        guard let value, value.count >= 10 else { return nil }
        return isoDayFormatter.date(from: String(value.prefix(10)))
    }

    static func tmdbDay(_ date: Date) -> String {
        isoDayFormatter.string(from: date)
    }

    static func tmdbDay(offsetDays: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offsetDays, to: Date()) ?? Date()
        return tmdbDay(date)
    }
}

// MARK: - Media helpers

extension MediaItem {
    /// Unique across movies and series (TMDB ids collide between the two).
    var nfKey: String { "\(mediaType)-\(id)" }

    var nfType: WatchType { isMovie ? .movie : .tv }

    var nfGenreTags: [String] { NF.genreTags(genreIds) }

    var releaseDateValue: Date? {
        NF.date(fromTMDB: isMovie ? releaseDate : firstAirDate)
    }

    var tmdbWebURL: URL? {
        URL(string: "https://www.themoviedb.org/\(isMovie ? "movie" : "tv")/\(id)")
    }

    /// Not released yet (future release / premiere date).
    var isUnreleased: Bool {
        guard let date = releaseDateValue else { return false }
        return date > Date()
    }

    /// Has artwork and isn't news or a talk show.
    var isListable: Bool {
        guard posterPath != nil else { return false }
        return Set(genreIds ?? []).isDisjoint(with: NF.excludedGenres)
    }

    /// Whether the title belongs on the rails: listable and already released.
    var isBrowsable: Bool {
        isListable && !isUnreleased
    }

    static func make(id: Int, type: WatchType, title: String, posterPath: String?, backdropPath: String? = nil, overview: String = "") -> MediaItem {
        MediaItem(
            id: id,
            mediaType: type == .movie ? "movie" : "tv",
            title: type == .movie ? title : nil,
            name: type == .tv ? title : nil,
            overview: overview,
            posterPath: posterPath,
            backdropPath: backdropPath
        )
    }
}

extension WatchType {
    var tmdbPath: String { self == .movie ? "movie" : "tv" }
}

// MARK: - Buttons

/// Dims and slightly shrinks on press — the shared feel for every tappable card.
struct NFPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

/// White primary action ("Play", "Resume").
struct NFPrimaryButtonLabel: View {
    var title: String = "Play"
    var systemImage: String = "play.fill"
    var height: CGFloat = 42

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.white, in: RoundedRectangle(cornerRadius: NF.buttonCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: NF.buttonCorner, style: .continuous))
    }
}

/// Translucent grey secondary action ("My List", "Trailer").
struct NFSecondaryButtonLabel: View {
    let title: String
    let systemImage: String
    var height: CGFloat = 42

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: NF.buttonCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: NF.buttonCorner, style: .continuous))
    }
}

/// Icon-over-label action used in rows of actions ("My List", "Rate", "Share").
struct NFIconActionLabel: View {
    let title: String
    let systemImage: String
    var isActive = false
    var activeColor: Color = .white

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(isActive ? activeColor : .white)
                .frame(height: 24)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NF.textSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 64)
        .contentShape(Rectangle())
    }
}

/// A round dark close/back control drawn over artwork.
struct NFRoundIconButton: View {
    let systemImage: String
    var size: CGFloat = 32
    var accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.62), in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Wordmark

/// The Nightflix wordmark used in the home header.
struct NFWordmark: View {
    var size: CGFloat = 27
    @Environment(\.nightflixAccent) private var accent

    var body: some View {
        Text("Nightflix")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .kerning(-0.4)
            .foregroundStyle(accent)
            .shadow(color: accent.opacity(0.55), radius: 10)
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel("Nightflix")
    }
}

// MARK: - Scroll offset

private struct NFScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Place on the first element inside a ScrollView's content; reports how far the
    /// content has scrolled (0 at rest, positive when scrolled down).
    func nfScrollOffsetMarker(in coordinateSpace: String) -> some View {
        background(alignment: .top) {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NFScrollOffsetKey.self,
                    value: -proxy.frame(in: .named(coordinateSpace)).minY
                )
            }
            .frame(height: 0)
        }
    }

    /// Apply to the ScrollView. Uses the scroll-geometry API where available (iOS 18+)
    /// and the content marker (`nfScrollOffsetMarker`) on iOS 17.
    @ViewBuilder
    func onNFScrollOffsetChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                action(offset)
            }
        } else {
            onPreferenceChange(NFScrollOffsetKey.self) { value in
                action(value)
            }
        }
    }
}
