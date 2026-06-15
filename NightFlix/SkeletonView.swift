import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(baseColor)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        let width = max(proxy.size.width, 1)
                        let travel = width * 2.25

                        LinearGradient(
                            colors: shimmerColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(width * 0.82, 82), height: proxy.size.height * 1.7)
                        .rotationEffect(.degrees(12))
                        .offset(x: isAnimating ? travel : -travel, y: -proxy.size.height * 0.32)
                    }
                    .clipped()
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .onAppear {
                startShimmerIfNeeded()
            }
            .onChange(of: reduceMotion) { _, _ in
                startShimmerIfNeeded()
            }
    }

    private var baseColor: Color {
        colorScheme == .dark ? .white.opacity(0.075) : Color(.systemGray5)
    }

    private var shimmerColors: [Color] {
        [
            .clear,
            .white.opacity(colorScheme == .dark ? 0.12 : 0.58),
            NightFlixStyle.accentColor.opacity(colorScheme == .dark ? 0.09 : 0.06),
            .clear
        ]
    }

    private func startShimmerIfNeeded() {
        guard !reduceMotion else {
            isAnimating = false
            return
        }

        isAnimating = false

        withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
}

struct TextLineSkeletonView: View {
    var width: CGFloat?
    var height: CGFloat = 12

    var body: some View {
        SkeletonView(cornerRadius: height / 2)
            .frame(width: width, height: height)
    }
}

struct PosterSkeletonView: View {
    var width: CGFloat?
    var height: CGFloat?
    var cornerRadius: CGFloat = 10

    var body: some View {
        SkeletonView(cornerRadius: cornerRadius)
            .frame(width: width, height: height)
    }
}

struct CardSkeletonView: View {
    var width: CGFloat = 152
    var posterWidth: CGFloat = 132
    var posterHeight: CGFloat = 198

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            PosterSkeletonView(width: posterWidth, height: posterHeight)

            TextLineSkeletonView(width: posterWidth * 0.86, height: 13)
            TextLineSkeletonView(width: posterWidth * 0.58, height: 11)

            SkeletonView(cornerRadius: 10)
                .frame(width: posterWidth, height: 37)
        }
        .padding(10)
        .frame(width: width, alignment: .topLeading)
        .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NightFlixStyle.borderColor(darkOpacity: 0.07), lineWidth: 1)
        }
    }
}

struct HeroBannerSkeletonView: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(0.76, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let bannerWidth = proxy.size.width
                    let bannerHeight = proxy.size.height

                    ZStack(alignment: .bottom) {
                        SkeletonView(cornerRadius: 0)
                            .overlay(alignment: .bottom) {
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        NightFlixStyle.backgroundColor.opacity(0.85),
                                        NightFlixStyle.backgroundColor
                                    ],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            }

                        VStack(spacing: 14) {
                            HStack(spacing: 8) {
                                TextLineSkeletonView(width: 74, height: 18)
                                TextLineSkeletonView(width: 120, height: 14)
                            }

                            HStack(spacing: 28) {
                                SkeletonView(cornerRadius: 8).frame(width: 48, height: 44)
                                SkeletonView(cornerRadius: 8).frame(width: 120, height: 44)
                                SkeletonView(cornerRadius: 8).frame(width: 48, height: 44)
                            }
                        }
                        .padding(.bottom, 22)
                    }
                    .frame(width: bannerWidth, height: bannerHeight)
                }
            }
    }
}

struct SearchResultSkeletonView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PosterSkeletonView(width: 86, height: 128)

            VStack(alignment: .leading, spacing: 10) {
                TextLineSkeletonView(width: 165, height: 15)
                TextLineSkeletonView(width: 96, height: 18)
                TextLineSkeletonView(width: nil, height: 11)
                TextLineSkeletonView(width: nil, height: 11)
                TextLineSkeletonView(width: 150, height: 11)

                SkeletonView(cornerRadius: 12)
                    .frame(height: 42)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .nightFlixResultCardStyle()
    }
}

struct DetailPageSkeletonView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                headerSkeleton

                VStack(alignment: .leading, spacing: 24) {
                    SkeletonView(cornerRadius: 8)
                        .frame(height: 48)

                    overviewSkeleton
                    castRowSkeleton
                    horizontalPosterRowSkeleton(title: "More Like This")
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 130)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var headerSkeleton: some View {
        ZStack(alignment: .bottom) {
            SkeletonView(cornerRadius: 0)

            LinearGradient(
                colors: [
                    .clear,
                    NightFlixStyle.backgroundColor.opacity(0.85),
                    NightFlixStyle.backgroundColor
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(spacing: 10) {
                TextLineSkeletonView(width: 210, height: 26)
                TextLineSkeletonView(width: 150, height: 13)
            }
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
    }

    private var overviewSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                TextLineSkeletonView(width: index == 3 ? 210 : nil, height: 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var castRowSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Cast")

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(0..<6, id: \.self) { _ in
                        VStack(spacing: 7) {
                            PosterSkeletonView(width: 76, height: 76, cornerRadius: 38)
                            TextLineSkeletonView(width: 64, height: 10)
                            TextLineSkeletonView(width: 48, height: 9)
                        }
                        .frame(width: 84)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func horizontalPosterRowSkeleton(title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: NightflixLayout.rowItemSpacing) {
                    ForEach(0..<5, id: \.self) { _ in
                        PosterSkeletonView(width: 110, height: 165, cornerRadius: NightflixLayout.posterCornerRadius)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SeasonSkeletonRowView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        PosterSkeletonView(width: 128, height: 192)
                        TextLineSkeletonView(width: 118, height: 12)
                        TextLineSkeletonView(width: 86, height: 10)
                        TextLineSkeletonView(width: 74, height: 10)
                    }
                    .padding(10)
                    .frame(width: 190, alignment: .topLeading)
                    .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(NightFlixStyle.borderColor, lineWidth: 1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EpisodeSkeletonListView: View {
    var count = 3

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 14) {
                        PosterSkeletonView(width: 124, height: 70)

                        VStack(alignment: .leading, spacing: 8) {
                            TextLineSkeletonView(width: 76, height: 10)
                            TextLineSkeletonView(width: 166, height: 14)
                            TextLineSkeletonView(width: 104, height: 10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SkeletonView(cornerRadius: 10)
                        .frame(height: 40)
                }
                .nightFlixResultCardStyle()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GenreChipSkeletonGrid: View {
    private let columns = [
        GridItem(.adaptive(minimum: 104), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(0..<12, id: \.self) { index in
                SkeletonView(cornerRadius: 14)
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .opacity(index % 3 == 0 ? 0.82 : 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PosterGridSkeletonView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(0..<9, id: \.self) { _ in
                PosterSkeletonView(width: nil, height: nil, cornerRadius: NightflixLayout.posterCornerRadius)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
            }
        }
    }
}

struct ResponsivePosterImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 10

    var body: some View {
        Color.clear
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    posterContent
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var posterContent: some View {
        if let url {
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
        } else {
            PosterFallbackView()
        }
    }
}

struct PosterFallbackView: View {
    var body: some View {
        ZStack {
            NightFlixStyle.fillColor(darkOpacity: 0.08)

            VStack(spacing: 6) {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3.weight(.bold))

                Text("Nightflix")
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(NightFlixStyle.mutedTextColor)
            .padding(8)
        }
    }
}
