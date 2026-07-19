import SwiftUI

/// Full-screen embedded player with loading and page-load error states.
struct PlayerView: View {
    let item: WatchItem
    var continueWatchingManager: ContinueWatchingManager?

    /// Persist `timeupdate` no more often than every few seconds of playback.
    private static let persistThreshold: Double = 5
    /// Treat playback past this fraction as "finished".
    private static let completionFraction: Double = 0.95

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lastPersistedSeconds: Double = -.greatestFiniteMagnitude

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebView(
                url: item.generatedURL,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onPlayerEvent: handlePlayerEvent
            )
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

    private func handlePlayerEvent(_ event: VideasyPlayerEvent) {
        // Only act on events for the title we launched (ignore unrelated frames).
        guard let continueWatchingManager, event.id == item.tmdbId else { return }

        // Videasy streams periodic progress updates only (no discrete "ended" event), so
        // a finished movie is inferred once it's effectively fully watched and then
        // leaves the rail. A series is left to advance via its own next-episode events.
        if item.type == .movie, event.fraction >= Self.completionFraction {
            continueWatchingManager.markFinished(type: item.type, tmdbId: item.tmdbId)
            return
        }

        // Throttle the continuous progress stream to persist at most every few seconds.
        if abs(event.currentTime - lastPersistedSeconds) < Self.persistThreshold {
            return
        }
        lastPersistedSeconds = event.currentTime

        let matchesLaunchedEpisode = event.season == item.season && event.episode == item.episode

        continueWatchingManager.recordProgress(
            type: item.type,
            tmdbId: item.tmdbId,
            title: item.title,
            posterPath: item.posterPath,
            season: event.season ?? item.season,
            episode: event.episode ?? item.episode,
            episodeName: matchesLaunchedEpisode ? item.episodeName : nil,
            positionSeconds: event.currentTime,
            durationSeconds: event.duration
        )
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
                generatedURL: URL(string: "https://player.videasy.net/movie/1078605?color=e50914&overlay=true")!
            )
        )
    }
}
