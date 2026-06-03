import SwiftUI

struct HomeStickyHeaderView: View {
    static let contentHeight: CGFloat = 84
    static let scrollContentSpacing: CGFloat = 14

    let scrollOffset: CGFloat
    let topSafeArea: CGFloat
    let showTitle: Bool
    let shouldAnimateTitle: Bool
    let showMenuButton: Bool
    let showSearchShortcut: Bool
    let animationsEnabled: Bool
    let onHomeTitle: () -> Void
    let onSearchShortcut: () -> Void
    let onOpenMenu: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var isTitleGlowVisible = true
    @State private var isTitlePressed = false
    @State private var titleGlowOffset: CGSize = .zero
    @State private var titlePressStartedAt: Date?
    @State private var titlePressMaximumDistance: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: max(topSafeArea, 0))

            HStack(alignment: .center, spacing: 12) {
                title

                Spacer(minLength: 12)

                if showSearchShortcut {
                    searchShortcutButton
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }

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
            .animation(searchShortcutAnimation, value: showSearchShortcut)

            Rectangle()
                .fill(headerDividerColor)
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .background(alignment: .top) {
            headerBackground
        }
        .shadow(color: headerShadowColor, radius: 18, y: 10)
        .onAppear {
            updateTitleGlowVisibility(for: backgroundProgress, animated: false)
        }
        .onChange(of: backgroundProgress) { _, newValue in
            updateTitleGlowVisibility(for: newValue, animated: true)
        }
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
            .nightflixTitleGlow(opacity: titleGlowOpacity, scale: titleGlowScale, offset: titleGlowOffset)
            .shadow(color: NightFlixStyle.titleGlowColor.opacity(titleGlowOpacity), radius: titleGlowRadius)
            .shadow(color: NightFlixStyle.titleSecondaryGlowColor.opacity(titleGlowOpacity), radius: titleSecondaryGlowRadius)
            .scaleEffect(titleScale, anchor: .leading)
            .animation(titlePressAnimation, value: isTitlePressed)
            .animation(titlePressAnimation, value: titleGlowOffset)
            .contentShape(Rectangle())
            .gesture(titlePressGesture)
            .accessibilityLabel("Home")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onHomeTitle()
            }
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

    private var searchShortcutButton: some View {
        Button {
            onSearchShortcut()
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(menuForegroundColor)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to search")
    }

    @ViewBuilder
    private var headerBackground: some View {
        if colorScheme == .dark {
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
        } else {
            Color.white
                .opacity(backgroundProgress)
                .frame(height: max(topSafeArea, 0) + headerContentHeight + 1)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var backgroundProgress: CGFloat {
        guard animationsEnabled, !reduceMotion else {
            return scrollOffset > 18 ? 1 : 0
        }

        return min(max((scrollOffset - 12) / 176, 0), 1)
    }

    private var headerContentHeight: CGFloat {
        Self.contentHeight
    }

    private var titleSize: CGFloat {
        38
    }

    private var titleScale: CGFloat {
        isTitlePressed ? 1.12 : 1
    }

    private var titleGlowScale: CGFloat {
        isTitlePressed ? 1.36 : 1
    }

    private var menuForegroundColor: Color {
        if colorScheme == .dark {
            return .white
        }

        return NightFlixStyle.primaryTextColor
    }

    private var headerDividerColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.08 * backgroundProgress)
        }

        return Color.black.opacity(0.22 * backgroundProgress)
    }

    private var headerShadowColor: Color {
        let opacity = colorScheme == .dark ? 0.3 : 0.08
        return .black.opacity(opacity * backgroundProgress)
    }

    private var titleGlowOpacity: CGFloat {
        isTitleGlowVisible ? 1 : 0
    }

    private var titleGlowRadius: CGFloat {
        isTitlePressed ? 22 : 16
    }

    private var titleSecondaryGlowRadius: CGFloat {
        isTitlePressed ? 46 : 34
    }

    private var searchShortcutAnimation: Animation? {
        guard animationsEnabled, !reduceMotion else { return nil }
        return .easeOut(duration: 0.18)
    }

    private var titlePressAnimation: Animation? {
        guard animationsEnabled, !reduceMotion else { return nil }
        return .interactiveSpring(response: 0.22, dampingFraction: 0.72)
    }

    private var titlePressGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if titlePressStartedAt == nil {
                    titlePressStartedAt = Date()
                    titlePressMaximumDistance = 0

                    withAnimation(titlePressAnimation) {
                        isTitlePressed = true
                    }
                }

                titlePressMaximumDistance = max(titlePressMaximumDistance, distance(for: value.translation))

                withAnimation(titlePressAnimation) {
                    titleGlowOffset = clampedGlowOffset(for: value.translation)
                }
            }
            .onEnded { value in
                let pressDuration = Date().timeIntervalSince(titlePressStartedAt ?? Date())
                let didTap = pressDuration < 0.28 && max(titlePressMaximumDistance, distance(for: value.translation)) < 10

                titlePressStartedAt = nil
                titlePressMaximumDistance = 0

                withAnimation(titlePressAnimation) {
                    isTitlePressed = false
                    titleGlowOffset = .zero
                }

                if didTap {
                    onHomeTitle()
                }
            }
    }

    private func clampedGlowOffset(for translation: CGSize) -> CGSize {
        let proposedOffset = CGSize(width: translation.width * 0.48, height: translation.height * 0.48)
        let maximumDistance: CGFloat = 24
        let proposedDistance = distance(for: proposedOffset)

        guard proposedDistance > maximumDistance else {
            return proposedOffset
        }

        let scale = maximumDistance / proposedDistance
        return CGSize(width: proposedOffset.width * scale, height: proposedOffset.height * scale)
    }

    private func distance(for size: CGSize) -> CGFloat {
        sqrt(size.width * size.width + size.height * size.height)
    }

    private func updateTitleGlowVisibility(for progress: CGFloat, animated: Bool) {
        let nextVisibility: Bool?

        if progress <= 0 {
            nextVisibility = true
        } else if progress >= 1 {
            nextVisibility = false
        } else {
            nextVisibility = nil
        }

        guard let nextVisibility, nextVisibility != isTitleGlowVisible else { return }

        guard animated, animationsEnabled, !reduceMotion else {
            var transaction = Transaction()
            transaction.animation = nil

            withTransaction(transaction) {
                isTitleGlowVisible = nextVisibility
            }
            return
        }

        withAnimation(.easeOut(duration: 0.24)) {
            isTitleGlowVisible = nextVisibility
        }
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
            showSearchShortcut: true,
            animationsEnabled: true,
            onHomeTitle: { },
            onSearchShortcut: { },
            onOpenMenu: { }
        )
    }
}
