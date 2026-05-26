import SwiftUI

struct HomeStickyHeaderView: View {
    static let expandedContentHeight: CGFloat = 92
    static let scrollContentSpacing: CGFloat = 14

    let scrollOffset: CGFloat
    let topSafeArea: CGFloat
    let showTitle: Bool
    let shouldAnimateTitle: Bool
    let showMenuButton: Bool
    let animationsEnabled: Bool
    let onOpenMenu: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(topSafeArea, 0))

            HStack(alignment: .center, spacing: 12) {
                title

                Spacer(minLength: 12)

                HomeMenuButton(foregroundColor: menuForegroundColor) {
                    onOpenMenu()
                }
                .nightflixEntrance(
                    isVisible: showMenuButton,
                    delay: 0.28,
                    yOffset: 10,
                    scaleAmount: 0.96,
                    animationsEnabled: animationsEnabled
                )
            }
            .padding(.horizontal, 20)
            .frame(height: headerContentHeight, alignment: .center)

            Rectangle()
                .fill(Color.white.opacity(0.08 * headerProgress))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            headerBackground
        }
        .shadow(color: .black.opacity(0.28 * headerProgress), radius: 16, y: 10)
    }

    static func scrollContentTopPadding(topSafeArea: CGFloat) -> CGFloat {
        max(topSafeArea, 0) + expandedContentHeight + scrollContentSpacing
    }

    private var title: some View {
        Text("Nightflix")
            .font(.system(size: titleSize, weight: .bold, design: .rounded))
            .foregroundStyle(NightFlixStyle.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .nightflixTitleGlow()
            .shadow(color: NightFlixStyle.titleGlowColor.opacity(titleGlowOpacity), radius: titleGlowRadius)
            .shadow(color: NightFlixStyle.titleSecondaryGlowColor.opacity(titleGlowOpacity), radius: titleSecondaryGlowRadius)
            .nightflixEntrance(
                isVisible: showTitle,
                delay: 0.1,
                yOffset: 14,
                scaleAmount: 0.98,
                reduceMotionDuration: 0,
                animationsEnabled: shouldAnimateTitle
            )
            .layoutPriority(1)
    }

    private var headerBackground: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .opacity(headerBackgroundOpacity)

            LinearGradient(
                colors: [
                    Color.black.opacity(topGradientOpacity),
                    Color.black.opacity(topGradientOpacity * 0.56),
                    Color.black.opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(1 - headerProgress)
        }
        .frame(height: max(topSafeArea, 0) + headerContentHeight + 1)
        .ignoresSafeArea(edges: .top)
    }

    private var headerProgress: CGFloat {
        let rawProgress = min(max(scrollOffset / 92, 0), 1)

        guard animationsEnabled, !reduceMotion else {
            return scrollOffset > 18 ? 1 : 0
        }

        return rawProgress
    }

    private var headerContentHeight: CGFloat {
        compactContentHeight + (Self.expandedContentHeight - compactContentHeight) * (1 - headerProgress)
    }

    private var titleSize: CGFloat {
        let expandedSize: CGFloat = reduceMotion ? 42 : 50
        let compactSize: CGFloat = 32
        return compactSize + (expandedSize - compactSize) * (1 - headerProgress)
    }

    private var headerBackgroundOpacity: CGFloat {
        min(headerProgress * 1.05, 1)
    }

    private var topGradientOpacity: CGFloat {
        colorScheme == .dark ? 0.36 : 0.22
    }

    private var menuForegroundColor: Color {
        if colorScheme == .dark || headerProgress > 0.42 {
            return .white
        }

        return NightFlixStyle.primaryTextColor
    }

    private var titleGlowOpacity: CGFloat {
        colorScheme == .dark ? 1 - (headerProgress * 0.22) : 1
    }

    private var titleGlowRadius: CGFloat {
        16 - (headerProgress * 6)
    }

    private var titleSecondaryGlowRadius: CGFloat {
        34 - (headerProgress * 12)
    }

    private var compactContentHeight: CGFloat {
        reduceMotion ? 60 : 58
    }
}

#Preview {
    ZStack(alignment: .top) {
        NightFlixStyle.backgroundColor.ignoresSafeArea()

        HomeStickyHeaderView(
            scrollOffset: 96,
            topSafeArea: 54,
            showTitle: true,
            shouldAnimateTitle: false,
            showMenuButton: true,
            animationsEnabled: true,
            onOpenMenu: { }
        )
    }
}
