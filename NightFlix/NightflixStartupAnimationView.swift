import SwiftUI

/// The launch intro: the Nightflix wordmark builds letter by letter, a light sweep and a
/// "tu-dum" punch, then the tagline, before handing off to the app.
struct NightflixStartupAnimationView: View {
    let animationsEnabled: Bool
    let onFinished: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false
    @State private var visibleLetters = Set<Int>()
    @State private var glowProgress = 0.0
    @State private var glowFlare = 0.0
    @State private var sweepProgress = -1.0
    @State private var showSweep = false
    @State private var punchScale = 1.0
    @State private var taglineOpacity = 0.0
    @State private var taglineOffset = 18.0
    @State private var contentOpacity = 1.0
    @State private var contentScale = 0.96

    private let wordmarkLetters = Array("Nightflix")
    private let letterSpacing: CGFloat = 1
    private let wordmarkFontSize: CGFloat = 46

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [accentColor.opacity(0.20 * max(glowProgress, glowFlare)), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 340
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                wordmark
                tagline
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)
            }
            .padding(.horizontal, 28)
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
        }
        .accessibilityHidden(true)
        .task {
            await runAnimationIfNeeded()
        }
        .onChange(of: animationsEnabled) { _, enabled in
            if !enabled {
                onFinished()
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                onFinished()
            }
        }
    }

    private var wordmark: some View {
        baseWordmark
            .overlay { sweepOverlay }
            .scaleEffect(punchScale)
            .background {
                Ellipse()
                    .fill(accentColor)
                    .frame(width: 300, height: 108)
                    .scaleEffect(0.65 + glowProgress * 0.45 + glowFlare * 0.55)
                    .opacity(0.42 * glowProgress + 0.5 * glowFlare)
                    .blur(radius: 55)
                    .allowsHitTesting(false)
            }
    }

    private var baseWordmark: some View {
        HStack(spacing: letterSpacing) {
            ForEach(Array(wordmarkLetters.enumerated()), id: \.offset) { index, character in
                letterText(character, index: index, color: accentColor, animated: true)
            }
        }
        .shadow(color: accentColor.opacity(0.55 * max(glowProgress, glowFlare)), radius: 18)
        .shadow(color: accentColor.opacity(0.3), radius: 40)
    }

    private func letterText(_ character: Character, index: Int, color: Color, animated: Bool) -> some View {
        let isShown = !animated || visibleLetters.contains(index)

        return Text(String(character))
            .font(.system(size: wordmarkFontSize, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .opacity(animated ? (isShown ? 1 : 0) : 1)
            .offset(y: (animated && !isShown) ? 32 : 0)
            .blur(radius: (animated && !isShown) ? 11 : 0)
            .scaleEffect((animated && !isShown) ? 0.55 : 1, anchor: .bottom)
    }

    private var sweepOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            if showSweep {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.95), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.5, height: height * 2.4)
                .rotationEffect(.degrees(20))
                .position(x: width / 2 + sweepProgress * width, y: height / 2)
                .blendMode(.plusLighter)
            }
        }
        .mask { maskWordmark }
        .allowsHitTesting(false)
    }

    private var maskWordmark: some View {
        HStack(spacing: letterSpacing) {
            ForEach(Array(wordmarkLetters.enumerated()), id: \.offset) { index, character in
                letterText(character, index: index, color: .white, animated: false)
            }
        }
    }

    private var tagline: some View {
        HStack(spacing: 0) {
            Text("an app by ")
                .foregroundStyle(.white.opacity(0.74))

            Text("Frizzle")
                .foregroundStyle(frizzleBlue)
                .nightflixSloganGlow(color: frizzleBlue)
        }
        .font(.system(size: 22, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }

    private var accentColor: Color {
        NightFlixStyle.accentColor
    }

    private var frizzleBlue: Color {
        Color(hex: "2F80FF")
    }

    @MainActor
    private func runAnimationIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        withAnimation(.easeOut(duration: 0.7)) {
            glowProgress = 1
            contentScale = 1
        }

        for index in wordmarkLetters.indices {
            guard animationsEnabled, !reduceMotion else {
                onFinished()
                return
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) {
                _ = visibleLetters.insert(index)
            }

            if index == 4 {
                HapticManager.shared.softImpact()
            }

            try? await Task.sleep(for: .milliseconds(62))
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        // Light sweep across the wordmark.
        showSweep = true
        sweepProgress = -1
        withAnimation(.easeInOut(duration: 0.62)) {
            sweepProgress = 1
        }

        // "tu-dum" punch at the peak of the sweep.
        try? await Task.sleep(for: .milliseconds(230))
        HapticManager.shared.heavyImpact()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.45)) {
            punchScale = 1.07
            glowFlare = 1
        }

        try? await Task.sleep(for: .milliseconds(85))
        HapticManager.shared.rigidImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            punchScale = 1
        }
        withAnimation(.easeOut(duration: 0.8)) {
            glowFlare = 0
        }

        // Reveal the tagline.
        try? await Task.sleep(for: .milliseconds(150))
        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        showSweep = false
        withAnimation(.easeOut(duration: 0.55)) {
            taglineOpacity = 1
            taglineOffset = 0
        }

        try? await Task.sleep(for: .milliseconds(840))
        guard animationsEnabled, !reduceMotion else {
            onFinished()
            return
        }

        // Zoom away to hand off to the app.
        withAnimation(.easeIn(duration: 0.5)) {
            contentOpacity = 0
            contentScale = 1.16
        }

        try? await Task.sleep(for: .milliseconds(520))
        onFinished()
    }
}

private extension View {
    func nightflixSloganGlow(color: Color) -> some View {
        modifier(NightflixSloganGlowModifier(color: color))
    }
}

private struct NightflixSloganGlowModifier: ViewModifier {

    let color: Color

    func body(content: Content) -> some View {
        content
            .background(alignment: .center) {
                Circle()
                    .fill(color)
                    .frame(width: 92, height: 34)
                    .opacity(glowOpacity)
                    .blur(radius: 18)
                    .allowsHitTesting(false)
            }
            .shadow(color: color.opacity(primaryShadowOpacity), radius: 12)
            .shadow(color: color.opacity(secondaryShadowOpacity), radius: 24)
    }

    private var glowOpacity: Double {
        0.18
    }

    private var primaryShadowOpacity: Double {
        0.82
    }

    private var secondaryShadowOpacity: Double {
        0.48
    }
}

#Preview {
    NightflixStartupAnimationView(animationsEnabled: true) {}
}
