import SwiftUI

/// Full-screen embedded player with loading and page-load error states.
struct PlayerView: View {
    let item: WatchItem

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebView(url: item.generatedURL, isLoading: $isLoading, errorMessage: $errorMessage)
                .ignoresSafeArea(edges: .bottom)

            closeButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.2)
                    .padding(24)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(NightFlixStyle.accentColor)

                    Text("Page failed to load")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .multilineTextAlignment(.center)

                    VStack(spacing: 5) {
                        Text("Tried opening")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.58))

                        Text(item.generatedURL.absoluteString)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }

                    Button("Close") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(NightFlixStyle.accentColor, in: Capsule())
                }
                .padding(22)
                .frame(maxWidth: 380)
                .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                HapticManager.shared.error()
            }
        }
    }

    private var closeButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.64), in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.34), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
        .padding(.leading, 12)
        .accessibilityLabel("Close player")
    }
}

#Preview {
    NavigationStack {
        PlayerView(
            item: WatchItem(
                type: .movie,
                title: "Sample Movie",
                tmdbId: "1078605",
                generatedURL: URL(string: "https://example.com/embed/movie/1078605?color=e50914&autoPlay=true&nextEpisode=true&episodeSelector=true")!
            )
        )
    }
}
