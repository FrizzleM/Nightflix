import SwiftUI

struct SkeletonView: View {
    var cornerRadius: CGFloat = 10

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        .white.opacity(0.075)
    }

    private var shimmerColors: [Color] {
        [
            .clear,
            .white.opacity(0.12),
            NightFlixStyle.accentColor.opacity(0.09),
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
