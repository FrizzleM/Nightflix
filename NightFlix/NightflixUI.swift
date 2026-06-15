import SwiftUI

// MARK: - Layout constants

/// Shared sizing for the Netflix-style poster experience.
enum NightflixLayout {
    /// Horizontal inset used for section headers and the leading/trailing edge of rows.
    static let screenPadding: CGFloat = 16
    /// Gap between posters inside a horizontal row.
    static let rowItemSpacing: CGFloat = 9
    /// Vertical spacing between a section header and its content.
    static let sectionHeaderSpacing: CGFloat = 11
    /// Vertical spacing between feed sections.
    static let sectionSpacing: CGFloat = 26
    /// Standard poster width used across rows.
    static let posterWidth: CGFloat = 116
    /// Standard poster corner radius — small, like Netflix art tiles.
    static let posterCornerRadius: CGFloat = 7

    static var posterHeight: CGFloat { posterWidth * 1.5 }
}

// MARK: - Pressable button style

/// Subtle press-scale used for tappable artwork, mirroring Netflix's tile feedback.
/// The haptic is fired once by the button's action, so a press feels like a single
/// crisp tick rather than a press-down/release double.
struct NightflixPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var pressedScale: CGFloat = 0.93

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? pressedScale : 1))
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Section header

/// Clean, image-forward section header. Optionally tappable with a trailing chevron.
struct NightflixSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button {
                HapticManager.shared.selection()
                action()
            } label: {
                headerContent(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
        } else {
            headerContent(showsChevron: false)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func headerContent(showsChevron: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(NightFlixStyle.secondaryTextColor)
                    .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bare poster image

/// A bare, art-forward poster image with rounded corners and a hairline edge.
struct NightflixPoster: View {
    let url: URL?
    var width: CGFloat? = nil
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = NightflixLayout.posterCornerRadius
    var aspectRatio: CGFloat = 2.0 / 3.0

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let width, let height {
            phaseImage
                .frame(width: width, height: height)
        } else {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        phaseImage
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
        }
    }

    private var phaseImage: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                PosterSkeletonView(width: nil, height: nil, cornerRadius: cornerRadius)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                PosterFallbackView()
            @unknown default:
                PosterFallbackView()
            }
        }
        .clipped()
    }
}

// MARK: - Poster card (tappable tile in a row)

/// A tappable bare poster used throughout horizontal rows.
struct PosterCard: View {
    let url: URL?
    var width: CGFloat = NightflixLayout.posterWidth
    var progress: Double? = nil
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.pop()
            action()
        } label: {
            VStack(spacing: 0) {
                NightflixPoster(url: url, width: width, height: width * 1.5)

                if let progress {
                    NightflixProgressBar(progress: progress)
                        .frame(width: width)
                        .padding(.top, 6)
                }
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle())
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Thin red-on-track progress indicator, like a watch-progress bar.
struct NightflixProgressBar: View {
    let progress: Double

    @Environment(\.nightflixAccent) private var accentColor

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))

                Capsule()
                    .fill(accentColor)
                    .frame(width: max(4, proxy.size.width * clampedProgress))
            }
        }
        .frame(height: 3)
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

// MARK: - Top 10 card

/// Netflix "Top 10" tile: a large rank numeral beside the poster art.
struct Top10PosterCard: View {
    let rank: Int
    let url: URL?
    var posterWidth: CGFloat = 104
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.pop()
            action()
        } label: {
            HStack(alignment: .bottom, spacing: -14) {
                rankNumber
                NightflixPoster(url: url, width: posterWidth, height: posterWidth * 1.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle())
        .accessibilityLabel("Number \(rank), \(accessibilityLabel)")
    }

    private var rankNumber: some View {
        Text("\(rank)")
            .font(.system(size: posterWidth * 1.5, weight: .heavy, design: .rounded))
            .foregroundStyle(rankGradient)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 3)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(height: posterWidth * 1.5, alignment: .bottom)
            .fixedSize()
            .padding(.bottom, -6)
    }

    private var rankGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.30),
                Color.white.opacity(0.12)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Continue watching tile

/// A continue-watching tile: poster art, progress bar, play glyph overlay and a title.
struct ContinueWatchingTile: View {
    let title: String
    let subtitle: String?
    let url: URL?
    var width: CGFloat = 138
    var progress: Double? = nil
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.pop()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack {
                    NightflixPoster(url: url, width: width, height: width * 1.5)

                    Circle()
                        .fill(.black.opacity(0.45))
                        .frame(width: 42, height: 42)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .overlay {
                            Circle().strokeBorder(.white.opacity(0.75), lineWidth: 1.5)
                        }
                }
                .overlay(alignment: .bottom) {
                    if let progress, progress > 0.01 {
                        NightflixProgressBar(progress: progress)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                    }
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(1)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(NightFlixStyle.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle())
        .accessibilityLabel("Continue \(title)")
    }
}

// MARK: - MyList interop

extension MyListItem {
    /// Build a list item from a lightweight catalogue `MediaItem`.
    init?(mediaItem: MediaItem) {
        guard let mediaType = MediaType(tmdbValue: mediaItem.mediaType) else { return nil }
        self.init(
            mediaType: mediaType,
            tmdbId: mediaItem.id,
            title: mediaItem.displayTitle,
            posterPath: mediaItem.posterPath,
            backdropPath: mediaItem.backdropPath,
            overview: mediaItem.overview,
            year: mediaItem.displayYear,
            dateAdded: Date()
        )
    }
}

// MARK: - Pill metadata badge

/// Small uppercase pill used for type/quality badges.
struct NightflixBadge: View {
    let text: String
    var filled: Bool = false

    @Environment(\.nightflixAccent) private var accentColor

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .tracking(0.4)
            .lineLimit(1)
            .foregroundStyle(filled ? .white : .white.opacity(0.92))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                filled ? AnyShapeStyle(accentColor) : AnyShapeStyle(Color.white.opacity(0.16)),
                in: Capsule()
            )
    }
}
