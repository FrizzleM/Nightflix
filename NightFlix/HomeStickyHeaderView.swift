import SwiftUI

struct HomeStickyHeaderView: View {
    static let contentHeight: CGFloat = 84
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
            .frame(height: Self.contentHeight, alignment: .center)

            Rectangle()
                .fill(Color.white.opacity(0.08 * backgroundProgress))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            headerBackground
        }
        .shadow(color: .black.opacity(0.3 * backgroundProgress), radius: 18, y: 10)
    }

    static func scrollContentTopPadding(topSafeArea: CGFloat) -> CGFloat {
        max(topSafeArea, 0) + contentHeight + scrollContentSpacing
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
                .opacity(0.92 * backgroundProgress)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.98),
                    Color.black.opacity(0.94),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(backgroundProgress)
        }
        .frame(height: max(topSafeArea, 0) + headerContentHeight + 1)
        .ignoresSafeArea(edges: .top)
    }

    private var backgroundProgress: CGFloat {
        guard animationsEnabled, !reduceMotion else {
            return scrollOffset > 18 ? 1 : 0
        }

        return min(max((scrollOffset - 12) / 88, 0), 1)
    }

    private var headerContentHeight: CGFloat {
        Self.contentHeight
    }

    private var titleSize: CGFloat {
        38
    }

    private var menuForegroundColor: Color {
        if colorScheme == .dark || backgroundProgress > 0.35 {
            return .white
        }

        return NightFlixStyle.primaryTextColor
    }

    private var titleGlowOpacity: CGFloat {
        colorScheme == .dark ? 1 - (backgroundProgress * 0.16) : 1
    }

    private var titleGlowRadius: CGFloat {
        16 - (backgroundProgress * 4)
    }

    private var titleSecondaryGlowRadius: CGFloat {
        34 - (backgroundProgress * 10)
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
