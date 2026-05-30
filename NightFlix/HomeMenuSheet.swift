import SwiftUI

enum HomeMenuDestination: String, Identifiable {
    case myList
    case categories
    case settings

    var id: String { rawValue }
}

struct HomeMenuSheet: View {
    private let itemCount = 6
    private let itemStaggerDelay = 0.055
    private let itemAnimationCompletionPadding = 0.18
    private let backdropAnimationDuration = 0.24

    let isPresented: Bool
    let animationsEnabled: Bool
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onSettings: () -> Void
    let onDonate: () -> Void
    let onDiscord: () -> Void
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var shouldRender = false
    @State private var areItemsPresented = false
    @State private var backdropOpacity = 0.0
    @State private var renderCycle = 0

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top > 0 ? proxy.safeAreaInsets.top : 44
            let safeBottom = proxy.safeAreaInsets.bottom > 0 ? proxy.safeAreaInsets.bottom : 24
            let maxButtonWidth = min(proxy.size.width - 40, 360)

            ZStack {
                if shouldRender {
                    overlayColor
                        .ignoresSafeArea()
                        .background(.ultraThinMaterial)
                        .opacity(backdropOpacity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismiss()
                        }
                        .transition(overlayTransition)

                    HomeMenuButtonCluster(
                        safeTop: safeTop,
                        safeBottom: safeBottom,
                        maxButtonWidth: maxButtonWidth,
                        isPresented: areItemsPresented,
                        animationsEnabled: animationsEnabled,
                        onClose: onDismiss,
                        onMyList: onMyList,
                        onCategories: onCategories,
                        onSettings: onSettings,
                        onDonate: onDonate,
                        onDiscord: onDiscord
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(isPresented)
        .animation(menuAnimation, value: isPresented)
        .onAppear {
            shouldRender = isPresented
            areItemsPresented = isPresented
            backdropOpacity = isPresented ? 1 : 0
        }
        .onChange(of: isPresented) { _, newValue in
            updateRenderedState(isPresented: newValue)
        }
    }

    private var menuAnimation: Animation? {
        animationsEnabled ? .interactiveSpring(response: 0.32, dampingFraction: 0.86) : nil
    }

    private var overlayTransition: AnyTransition {
        animationsEnabled ? .opacity : .identity
    }

    private var overlayColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.80) : Color.black.opacity(0.44)
    }

    private var itemAnimationDuration: Double {
        guard animationsEnabled else { return 0 }
        return Double(itemCount - 1) * itemStaggerDelay + itemAnimationCompletionPadding
    }

    private var closeAnimationDuration: Double {
        itemAnimationDuration + backdropAnimationDuration
    }

    private var backdropAnimation: Animation? {
        animationsEnabled ? .easeOut(duration: backdropAnimationDuration) : nil
    }

    private func updateRenderedState(isPresented: Bool) {
        renderCycle += 1
        let currentCycle = renderCycle

        if isPresented {
            let wasRendered = shouldRender
            shouldRender = true

            if !wasRendered {
                backdropOpacity = animationsEnabled ? 0 : 1
                areItemsPresented = false
            }

            guard animationsEnabled else {
                backdropOpacity = 1
                areItemsPresented = true
                return
            }

            DispatchQueue.main.async {
                guard renderCycle == currentCycle, self.isPresented else { return }

                withAnimation(backdropAnimation) {
                    backdropOpacity = 1
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + backdropAnimationDuration) {
                guard renderCycle == currentCycle, self.isPresented else { return }
                areItemsPresented = true
            }
            return
        }

        guard animationsEnabled else {
            areItemsPresented = false
            backdropOpacity = 0
            shouldRender = false
            return
        }

        areItemsPresented = false

        DispatchQueue.main.asyncAfter(deadline: .now() + itemAnimationDuration) {
            guard renderCycle == currentCycle, !self.isPresented else { return }

            withAnimation(backdropAnimation) {
                backdropOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + closeAnimationDuration) {
            guard renderCycle == currentCycle, !self.isPresented else { return }
            shouldRender = false
        }
    }

}

private struct HomeMenuButtonCluster: View {
    private let itemCount = 6

    let safeTop: CGFloat
    let safeBottom: CGFloat
    let maxButtonWidth: CGFloat
    let isPresented: Bool
    let animationsEnabled: Bool
    let onClose: () -> Void
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onSettings: () -> Void
    let onDonate: () -> Void
    let onDiscord: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var visibleItems = Set<Int>()
    @State private var itemAnimationCycle = 0

    var body: some View {
        VStack(spacing: 14) {
            closeButton
                .frame(maxWidth: maxButtonWidth, alignment: .trailing)
                .menuItemEntrance(isVisible: isItemVisible(0), index: 0)

            menuButton(title: "Watch Later", systemImage: "clock.fill", action: onMyList)
                .menuItemEntrance(isVisible: isItemVisible(1), index: 1)
            menuButton(title: "Categories", systemImage: "square.grid.2x2.fill", action: onCategories)
                .menuItemEntrance(isVisible: isItemVisible(2), index: 2)
            menuButton(title: "Donate", systemImage: "cup.and.saucer.fill", trailingSystemImage: "arrow.up.right", action: onDonate)
                .menuItemEntrance(isVisible: isItemVisible(3), index: 3)
            menuButton(title: "Join my Discord", systemImage: "bubble.left.and.bubble.right.fill", trailingSystemImage: "arrow.up.right", action: onDiscord)
                .menuItemEntrance(isVisible: isItemVisible(4), index: 4)
            menuButton(title: "Settings", systemImage: "gearshape.fill", isProminent: true, action: onSettings)
                .menuItemEntrance(isVisible: isItemVisible(5), index: 5)
        }
        .frame(maxWidth: maxButtonWidth)
        .padding(.top, safeTop + 24)
        .padding(.horizontal, 20)
        .padding(.bottom, safeBottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onAppear {
            updateItemVisibility(isPresented: isPresented)
        }
        .onChange(of: isPresented) { _, newValue in
            updateItemVisibility(isPresented: newValue)
        }
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(closeButtonForegroundColor)
                .frame(width: 48, height: 48)
                .background(closeButtonBackgroundColor, in: Circle())
                .overlay {
                    Circle()
                        .stroke(closeButtonStrokeColor, lineWidth: 1)
                }
                .shadow(color: closeButtonShadowColor, radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close menu")
    }

    private func menuButton(
        title: String,
        systemImage: String,
        trailingSystemImage: String = "chevron.right",
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor(isProminent: isProminent))
                        .frame(width: 44, height: 44)

                    Image(systemName: systemImage)
                        .font(.headline.weight(.black))
                        .foregroundStyle(iconForegroundColor(isProminent: isProminent))
                }

                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(buttonTextColor(isProminent: isProminent))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                Spacer(minLength: 0)

                Image(systemName: trailingSystemImage)
                    .font(.footnote.weight(.black))
                    .foregroundStyle(buttonTextColor(isProminent: isProminent).opacity(0.72))
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 72)
            .background(buttonBackground(isProminent: isProminent))
            .overlay { buttonStroke(isProminent: isProminent) }
            .shadow(color: buttonShadowColor, radius: 22, y: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func buttonBackground(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(buttonBackgroundColor)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                buttonHighlightColor(isProminent: isProminent),
                                buttonAccentWashColor(isProminent: isProminent),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
    }

    private func buttonStroke(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(
                buttonStrokeColor(isProminent: isProminent),
                lineWidth: isProminent ? 1.5 : 1
            )
    }

    private func iconBackgroundColor(isProminent: Bool) -> Color {
        if colorScheme == .dark {
            return isProminent ? NightFlixStyle.accentColor.opacity(0.28) : NightFlixStyle.accentColor.opacity(0.18)
        }

        return isProminent ? NightFlixStyle.accentColor.opacity(0.18) : NightFlixStyle.accentColor.opacity(0.12)
    }

    private func iconForegroundColor(isProminent: Bool) -> Color {
        NightFlixStyle.accentColor
    }

    private func buttonTextColor(isProminent: Bool) -> Color {
        colorScheme == .dark ? .white : .black
    }

    private var closeButtonForegroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var closeButtonBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var closeButtonStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    private var closeButtonShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.58) : Color.black.opacity(0.16)
    }

    private var buttonBackgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    private var buttonShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.62) : Color.black.opacity(0.12)
    }

    private func buttonStrokeColor(isProminent: Bool) -> Color {
        if isProminent {
            return NightFlixStyle.accentColor.opacity(colorScheme == .dark ? 0.72 : 0.78)
        }

        return colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
    }

    private func buttonHighlightColor(isProminent: Bool) -> Color {
        colorScheme == .dark ? Color.white.opacity(isProminent ? 0.12 : 0.08) : Color.white.opacity(0.92)
    }

    private func buttonAccentWashColor(isProminent: Bool) -> Color {
        if colorScheme == .dark {
            return NightFlixStyle.accentColor.opacity(isProminent ? 0.16 : 0.05)
        }

        return NightFlixStyle.accentColor.opacity(isProminent ? 0.08 : 0.03)
    }

    private func updateItemVisibility(isPresented: Bool) {
        itemAnimationCycle += 1

        if isPresented {
            animateItemsIn(cycle: itemAnimationCycle)
        } else {
            animateItemsOut(cycle: itemAnimationCycle)
        }
    }

    private func animateItemsIn(cycle: Int) {
        visibleItems = []

        guard animationsEnabled else {
            visibleItems = Set(0..<itemCount)
            return
        }

        for index in 0..<itemCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                guard itemAnimationCycle == cycle else { return }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82)) {
                    _ = visibleItems.insert(index)
                }
            }
        }
    }

    private func animateItemsOut(cycle: Int) {
        guard animationsEnabled else {
            visibleItems = []
            return
        }

        for index in (0..<itemCount).reversed() {
            let delay = Double(itemCount - 1 - index) * 0.055

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard itemAnimationCycle == cycle else { return }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82)) {
                    _ = visibleItems.remove(index)
                }
            }
        }
    }

    private func isItemVisible(_ index: Int) -> Bool {
        !animationsEnabled || visibleItems.contains(index)
    }
}

private struct MenuItemEntranceModifier: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(x: isVisible ? 0 : 96)
            .scaleEffect(isVisible ? 1 : 0.98, anchor: .trailing)
    }
}

private extension View {
    func menuItemEntrance(isVisible: Bool, index: Int) -> some View {
        modifier(MenuItemEntranceModifier(isVisible: isVisible, index: index))
    }
}
