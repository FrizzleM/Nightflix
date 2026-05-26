import SwiftUI

enum HomeMenuDestination: String, Identifiable {
    case myList
    case categories

    var id: String { rawValue }
}

struct HomeMenuSheet: View {
    let isPresented: Bool
    let animationsEnabled: Bool
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onDonate: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let screenWidth = proxy.size.width
            let maximumPanelWidth = min(360, screenWidth - 32)
            let panelWidth = max(1, min(max(screenWidth * 0.82, 280), maximumPanelWidth))
            let safeTop = proxy.safeAreaInsets.top > 0 ? proxy.safeAreaInsets.top : 44
            let safeBottom = proxy.safeAreaInsets.bottom > 0 ? proxy.safeAreaInsets.bottom : 24

            ZStack(alignment: .trailing) {
                if isPresented {
                    Color.black
                        .opacity(0.65)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onDismiss()
                        }
                        .transition(overlayTransition)

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        SideMenuPanel(
                            safeTop: safeTop,
                            safeBottom: safeBottom,
                            onClose: onDismiss,
                            onMyList: onMyList,
                            onCategories: onCategories,
                            onDonate: onDonate
                        )
                        .frame(width: panelWidth)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .transition(panelTransition)
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

    private var panelTransition: AnyTransition {
        animationsEnabled ? .move(edge: .trailing).combined(with: .opacity) : .identity
    }
}

private struct SideMenuPanel: View {
    let safeTop: CGFloat
    let safeBottom: CGFloat
    let onClose: () -> Void
    let onMyList: () -> Void
    let onCategories: () -> Void
    let onDonate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            titleRow

            VStack(spacing: 10) {
                menuRow(title: "My List", systemImage: "bookmark.fill", action: onMyList)
                menuRow(title: "Categories", systemImage: "square.grid.2x2.fill", action: onCategories)
                menuRow(title: "Donate", systemImage: "cup.and.saucer.fill", showsExternalIndicator: true, action: onDonate)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 16)

            Text("Nightflix")
                .font(.footnote.weight(.black))
                .foregroundStyle(.white.opacity(0.38))
        }
        .padding(.top, safeTop + 24)
        .padding(.horizontal, 24)
        .padding(.bottom, safeBottom + 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .clipShape(panelShape)
        .overlay {
            panelShape
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.45), radius: 26, x: -14, y: 0)
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            Text("Menu")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.09), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close menu")
        }
    }

    private func menuRow(
        title: String,
        systemImage: String,
        showsExternalIndicator: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.accentColor)
                    .frame(width: 28)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)

                Image(systemName: showsExternalIndicator ? "arrow.up.right" : "chevron.right")
                    .font(.footnote.weight(.black))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 60)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var panelShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 28,
            bottomLeadingRadius: 28,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }
}
