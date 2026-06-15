import SwiftUI

struct HeroBannerView: View {
    let item: MediaItem
    @ObservedObject var myListManager: MyListManager
    let onPlay: (MediaItem) -> Void
    let onMyList: (MediaItem) -> Void
    let onMoreInfo: (MediaItem) -> Void

    /// Ratio of width to height. Slightly taller than wide for a portrait billboard.
    private let heroAspectRatio: CGFloat = 0.76

    var body: some View {
        Color.clear
            .aspectRatio(heroAspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height

                    ZStack(alignment: .bottom) {
                        HeroArtworkImage(item: item)
                            .frame(width: width, height: height)
                            .clipped()

                        topScrim
                        bottomScrim(height: height)

                        VStack(spacing: 12) {
                            metadataLine
                            actionRow
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 22)
                        .frame(width: width)
                    }
                    .frame(width: width, height: height)
                }
            }
            .accessibilityElement(children: .contain)
    }

    // MARK: Scrims

    private var topScrim: some View {
        LinearGradient(
            colors: [.black.opacity(0.45), .clear],
            startPoint: .top,
            endPoint: .center
        )
    }

    private func bottomScrim(height: CGFloat) -> some View {
        LinearGradient(
            colors: [
                .clear,
                NightFlixStyle.backgroundColor.opacity(0.35),
                NightFlixStyle.backgroundColor.opacity(0.85),
                NightFlixStyle.backgroundColor
            ],
            startPoint: .center,
            endPoint: .bottom
        )
        .frame(height: height * 0.7)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: Metadata

    private var metadataLine: some View {
        HStack(spacing: 7) {
            NightflixBadge(text: "Featured", filled: true)

            Text(metadataText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.6), radius: 6, y: 2)
        }
    }

    private var metadataText: String {
        var parts: [String] = [item.type.displayName]
        if let year = item.displayYear, !year.isEmpty {
            parts.append(year)
        }
        return parts.joined(separator: "  •  ")
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 28) {
            secondaryAction(
                systemImage: isSaved ? "checkmark" : "plus",
                label: "My List"
            ) {
                onMyList(item)
            }

            playButton

            secondaryAction(systemImage: "info.circle", label: "Info") {
                onMoreInfo(item)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var playButton: some View {
        Button {
            onPlay(item)
        } label: {
            Label("Play", systemImage: "play.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 11)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(NightflixPressableStyle(pressedScale: 0.95))
        .accessibilityLabel("Play \(item.displayTitle)")
    }

    private func secondaryAction(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .frame(height: 24)

                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
            .frame(width: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle(pressedScale: 0.9))
        .accessibilityLabel("\(label) for \(item.displayTitle)")
    }

    private var isSaved: Bool {
        guard let mediaType = MediaType(tmdbValue: item.mediaType) else { return false }
        return myListManager.contains(mediaType: mediaType, tmdbId: item.id)
    }
}

struct HeroBannerPlaceholderView: View {
    var body: some View {
        HeroBannerSkeletonView()
    }
}

private struct HeroArtworkImage: View {
    let item: MediaItem

    var body: some View {
        if let url = item.posterURL ?? item.backdropURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    NightflixHeroPlaceholder()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    NightflixHeroPlaceholder()
                @unknown default:
                    NightflixHeroPlaceholder()
                }
            }
        } else {
            NightflixHeroPlaceholder()
        }
    }
}

private struct NightflixHeroPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.12, green: 0.02, blue: 0.03),
                    Color(red: 0.03, green: 0.03, blue: 0.04)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )

            LinearGradient(
                colors: [
                    NightFlixStyle.accentColor.opacity(0.34),
                    .clear
                ],
                startPoint: .bottomLeading,
                endPoint: .center
            )

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white.opacity(0.16))
        }
    }
}
