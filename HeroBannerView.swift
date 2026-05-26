import SwiftUI

struct HeroBannerView: View {
    let item: MediaItem
    let onPrimaryAction: (MediaItem) -> Void
    let onMoreInfo: (MediaItem) -> Void

    var body: some View {
        Color.clear
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 10.5, contentMode: .fit)
        .frame(minHeight: 280, maxHeight: 360)
        .overlay {
            GeometryReader { proxy in
                let bannerWidth = proxy.size.width
                let bannerHeight = proxy.size.height
                let horizontalPadding: CGFloat = bannerWidth < 360 ? 16 : 20
                let availableContentWidth = max(0, bannerWidth - horizontalPadding * 2)
                let contentWidth = min(availableContentWidth, bannerWidth * 0.74)
                let titleSize = min(34, max(28, bannerWidth * 0.082))

                ZStack(alignment: .bottomLeading) {
                    HeroBackdropImage(item: item)
                        .frame(width: bannerWidth, height: bannerHeight)
                        .clipped()

                    LinearGradient(
                        colors: [
                            .black.opacity(0.72),
                            .black.opacity(0.42),
                            .black.opacity(0.08),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(width: bannerWidth, height: bannerHeight)

                    LinearGradient(
                        colors: [
                            .black.opacity(0.58),
                            .black.opacity(0.24),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: bannerWidth, height: bannerHeight)

                    VStack(alignment: .leading, spacing: 7) {
                        metadata(contentWidth: contentWidth)
                        title(size: titleSize)
                        overview
                        actions(contentWidth: contentWidth)
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 16)
                }
                .frame(width: bannerWidth, height: bannerHeight)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.24), radius: 22, y: 12)
        .accessibilityElement(children: .contain)
    }

    private func metadata(contentWidth: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text("Featured")
                .font(.caption2.weight(.black))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(NightFlixStyle.accentColor, in: Capsule())

            Text(item.type.displayName)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white.opacity(0.90))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.white.opacity(0.15), in: Capsule())

            if let year = item.displayYear, !year.isEmpty {
                Text(year)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.12), in: Capsule())
            }
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private func title(size: CGFloat) -> some View {
        Text(item.displayTitle)
            .font(.system(size: size, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(2)
            .truncationMode(.tail)
            .minimumScaleFactor(0.80)
            .shadow(color: .black.opacity(0.55), radius: 7, y: 3)
    }

    @ViewBuilder
    private var overview: some View {
        if !item.overview.isEmpty {
            Text(item.overview)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(2)
                .truncationMode(.tail)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
        }
    }

    private func actions(contentWidth: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                primaryButton
                secondaryButton
            }
            .frame(width: contentWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                primaryButton
                secondaryButton
            }
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(width: contentWidth, alignment: .leading)
        .padding(.top, 2)
    }

    private var primaryButton: some View {
        Button {
            onPrimaryAction(item)
        } label: {
            Label("Play", systemImage: "play.fill")
                .font(.subheadline.weight(.bold))
                .imageScale(.small)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .frame(minHeight: 34)
                .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play \(item.displayTitle)")
    }

    private var secondaryButton: some View {
        Button {
            onMoreInfo(item)
        } label: {
            Label("More Info", systemImage: "info.circle")
                .font(.subheadline.weight(.bold))
                .imageScale(.small)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .frame(minHeight: 34)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More info for \(item.displayTitle)")
    }
}

struct HeroBannerPlaceholderView: View {
    var body: some View {
        HeroBannerSkeletonView()
    }
}

private struct HeroBackdropImage: View {
    let item: MediaItem

    var body: some View {
        if let url = item.backdropURL ?? item.posterURL {
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
