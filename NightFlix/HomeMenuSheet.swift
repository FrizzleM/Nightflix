import SwiftUI

enum HomeMenuDestination: String, Identifiable {
    case myList
    case categories
    case settings

    var id: String { rawValue }
}

struct HomeMenuSheet: View {
    let isPresented: Bool
    let animationsEnabled: Bool
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onSettings: () -> Void
    let onDonate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top > 0 ? proxy.safeAreaInsets.top : 44
            let safeBottom = proxy.safeAreaInsets.bottom > 0 ? proxy.safeAreaInsets.bottom : 24
            let maxButtonWidth = min(proxy.size.width - 40, 360)

            ZStack {
                if isPresented {
                    Color.black
                        .opacity(0.76)
                        .ignoresSafeArea()
                        .background(.regularMaterial)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismiss()
                        }
                        .transition(overlayTransition)

                    HomeMenuButtonCluster(
                        safeTop: safeTop,
                        safeBottom: safeBottom,
                        maxButtonWidth: maxButtonWidth,
                        animationsEnabled: animationsEnabled,
                        onClose: onDismiss,
                        onMyList: onMyList,
                        onCategories: onCategories,
                        onSettings: onSettings,
                        onDonate: onDonate
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(isPresented)
        .animation(menuAnimation, value: isPresented)
    }

    private var menuAnimation: Animation? {
        animationsEnabled ? .interactiveSpring(response: 0.32, dampingFraction: 0.86) : nil
    }

    private var overlayTransition: AnyTransition {
        animationsEnabled ? .opacity : .identity
    }

}

private struct HomeMenuButtonCluster: View {
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let maxButtonWidth: CGFloat
    let animationsEnabled: Bool
    let onClose: () -> Void
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onSettings: () -> Void
    let onDonate: () -> Void

    @State private var visibleItems = Set<Int>()

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
            menuButton(title: "Settings", systemImage: "gearshape.fill", isProminent: true, action: onSettings)
                .menuItemEntrance(isVisible: isItemVisible(4), index: 4)
        }
        .frame(maxWidth: maxButtonWidth)
        .padding(.top, safeTop + 24)
        .padding(.horizontal, 20)
        .padding(.bottom, safeBottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onAppear {
            animateItemsIn()
        }
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.58), radius: 18, y: 8)
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
            .shadow(color: .black.opacity(0.62), radius: 22, y: 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func buttonBackground(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.black)
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(isProminent ? 0.12 : 0.08),
                                NightFlixStyle.accentColor.opacity(isProminent ? 0.16 : 0.05),
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
                isProminent ? NightFlixStyle.accentColor.opacity(0.72) : Color.white.opacity(0.14),
                lineWidth: isProminent ? 1.5 : 1
            )
    }

    private func iconBackgroundColor(isProminent: Bool) -> Color {
        isProminent ? NightFlixStyle.accentColor.opacity(0.28) : NightFlixStyle.accentColor.opacity(0.18)
    }

    private func iconForegroundColor(isProminent: Bool) -> Color {
        NightFlixStyle.accentColor
    }

    private func buttonTextColor(isProminent: Bool) -> Color {
        if isProminent {
            return .white
        }

        return .white
    }

    private func animateItemsIn() {
        visibleItems = []

        guard animationsEnabled else {
            visibleItems = Set(0...4)
            return
        }

        for index in 0...4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.82)) {
                    _ = visibleItems.insert(index)
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
