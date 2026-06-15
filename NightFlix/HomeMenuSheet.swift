import SwiftUI

enum HomeMenuDestination: String, Identifiable {
    case myList
    case categories
    case settings

    var id: String { rawValue }
}

struct HomeMenuSheet: View {
    private let itemCount = 7
    private let itemStaggerDelay = 0.05
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
            let menuWidth = min(proxy.size.width - 32, 460)

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

                    HomeMenuContent(
                        safeTop: safeTop,
                        safeBottom: safeBottom,
                        menuWidth: menuWidth,
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
        colorScheme == .dark ? Color.black.opacity(0.86) : Color.black.opacity(0.42)
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

private struct HomeMenuContent: View {
    private let itemCount = 7

    let safeTop: CGFloat
    let safeBottom: CGFloat
    let menuWidth: CGFloat
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
        VStack(alignment: .leading, spacing: 0) {
            header
                .menuItemEntrance(isVisible: isItemVisible(0))
                .padding(.bottom, 22)

            Group {
                menuRow(index: 1, title: "Watch Later", systemImage: "clock", action: onMyList)
                rowDivider(index: 1)
                menuRow(index: 2, title: "Categories", systemImage: "square.grid.2x2", action: onCategories)
                rowDivider(index: 2)
                menuRow(index: 3, title: "Settings", systemImage: "gearshape", action: onSettings)
            }

            sectionLabel("Support")
                .menuItemEntrance(isVisible: isItemVisible(4))
                .padding(.top, 26)
                .padding(.bottom, 2)

            Group {
                menuRow(index: 5, title: "Donate", systemImage: "cup.and.saucer", isExternal: true, action: onDonate)
                rowDivider(index: 5)
                menuRow(index: 6, title: "Join my Discord", systemImage: "bubble.left.and.bubble.right", isExternal: true, action: onDiscord)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: menuWidth, alignment: .leading)
        .padding(.top, safeTop + 14)
        .padding(.horizontal, 24)
        .padding(.bottom, safeBottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onAppear {
            updateItemVisibility(isPresented: isPresented)
        }
        .onChange(of: isPresented) { _, newValue in
            updateItemVisibility(isPresented: newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Nightflix")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(NightFlixStyle.accentColor)
                .shadow(color: NightFlixStyle.titleGlowColor.opacity(0.9), radius: 14)
                .lineLimit(1)

            Spacer(minLength: 12)

            closeButton
        }
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.black))
                .foregroundStyle(primaryText)
                .frame(width: 40, height: 40)
                .background(closeButtonBackground, in: Circle())
                .overlay { Circle().strokeBorder(separatorColor, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close menu")
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(NightFlixStyle.tertiaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func menuRow(
        index: Int,
        title: String,
        systemImage: String,
        isExternal: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(primaryText)
                    .frame(width: 26, alignment: .center)

                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 8)

                Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(NightFlixStyle.tertiaryTextColor)
            }
            .padding(.vertical, 17)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
        .accessibilityLabel(title)
        .menuItemEntrance(isVisible: isItemVisible(index))
    }

    private func rowDivider(index: Int) -> some View {
        Rectangle()
            .fill(separatorColor)
            .frame(height: 1)
            .padding(.leading, 48)
            .menuItemEntrance(isVisible: isItemVisible(index))
    }

    private var primaryText: Color {
        colorScheme == .dark ? .white : .black
    }

    private var separatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.1)
    }

    private var closeButtonBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                guard itemAnimationCycle == cycle else { return }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84)) {
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
            let delay = Double(itemCount - 1 - index) * 0.05

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard itemAnimationCycle == cycle else { return }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84)) {
                    _ = visibleItems.remove(index)
                }
            }
        }
    }

    private func isItemVisible(_ index: Int) -> Bool {
        !animationsEnabled || visibleItems.contains(index)
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(highlightColor.opacity(configuration.isPressed ? 1 : 0))
            )
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }
}

private struct MenuItemEntranceModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 14)
    }
}

private extension View {
    func menuItemEntrance(isVisible: Bool) -> some View {
        modifier(MenuItemEntranceModifier(isVisible: isVisible))
    }
}
