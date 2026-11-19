import AVFoundation
import SwiftUI

/// Full-screen player: the provider's web player edge to edge, rotated to landscape on
/// iPhone, with a minimal auto-hiding top bar (back + title) that reappears whenever the
/// user touches the player, plus loading and failure states.
struct PlayerView: View {
    let item: WatchItem
    var continueWatchingManager: ContinueWatchingManager?

    /// Persist progress no more often than every few seconds of playback.
    private static let persistThreshold: Double = 5
    /// Treat playback past this fraction as "finished".
    private static let completionFraction: Double = 0.95
    /// How long the top bar stays up after the last touch.
    private static let chromeTimeout: Duration = .seconds(3.5)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.nightflixAccent) private var accent

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSourceUnavailable = false
    @State private var reloadToken = 0
    @State private var lastPersistedSeconds: Double = -.greatestFiniteMagnitude
    @State private var playingSeason: Int?
    @State private var playingEpisode: Int?
    @State private var isChromeVisible = true
    @State private var chromeHideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            WebView(
                url: item.generatedURL,
                reloadToken: reloadToken,
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                onMessage: handle
            )
            .ignoresSafeArea(edges: .bottom)

            if isLoading && errorMessage == nil && !isSourceUnavailable {
                loadingView
                    .transition(.opacity)
            }

            topBar

            if let errorMessage {
                failureCard(
                    title: "The player didn't load",
                    message: errorMessage
                )
            } else if isSourceUnavailable {
                failureCard(
                    title: "Not available right now",
                    message: "None of the player's servers could stream this title. Try again in a little while or pick another title."
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .onAppear {
            playingSeason = item.season
            playingEpisode = item.episode
            Self.activatePlaybackAudioSession()
            NFOrientation.enterPlayback()
            showChrome()
        }
        .onDisappear {
            chromeHideTask?.cancel()
            NFOrientation.exitPlayback()
            Self.deactivatePlaybackAudioSession()
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                HapticManager.shared.error()
            }
        }
    }

    // MARK: - Chrome

    private var topBar: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(titleLine)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 72)
                    .shadow(color: .black.opacity(0.6), radius: 6)
                    .allowsHitTesting(false)

                // The close control sits top-right: VidFast keeps its server picker in
                // the top-left corner.
                HStack {
                    Spacer()

                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .shadow(color: .black.opacity(0.6), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close player")
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .background(alignment: .top) {
                LinearGradient(
                    colors: [.black.opacity(0.72), .black.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 110)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
            }

            Spacer(minLength: 0)
        }
        .opacity(isChromeVisible ? 1 : 0)
        .allowsHitTesting(isChromeVisible)
        .animation(.easeInOut(duration: 0.25), value: isChromeVisible)
    }

    private var titleLine: String {
        guard item.type == .tv, let season = playingSeason, let episode = playingEpisode else {
            return item.title
        }

        let isLaunchedEpisode = season == item.season && episode == item.episode
        if isLaunchedEpisode, let name = item.episodeName, !name.isEmpty {
            return "\(item.title)  S\(season):E\(episode) “\(name)”"
        }

        return "\(item.title)  S\(season):E\(episode)"
    }

    private func showChrome() {
        isChromeVisible = true
        chromeHideTask?.cancel()
        chromeHideTask = Task { @MainActor in
            try? await Task.sleep(for: Self.chromeTimeout)
            guard !Task.isCancelled else { return }
            isChromeVisible = false
        }
    }

    // MARK: - Loading / failure

    private var loadingView: some View {
        VStack(spacing: 18) {
            NFLoadingRing(color: accent)
                .frame(width: 46, height: 46)

            Text(item.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .allowsHitTesting(false)
    }

    private func failureCard(title: String, message: String) -> some View {
        ZStack {
            Color.black.opacity(0.82)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        close()
                    } label: {
                        Text("Close")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        retry()
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 380)
        }
        .transition(.opacity)
    }

    private func retry() {
        HapticManager.shared.lightImpact()
        isSourceUnavailable = false
        errorMessage = nil
        isLoading = true
        reloadToken += 1
    }

    private func close() {
        HapticManager.shared.lightImpact()
        dismiss()
    }

    // MARK: - Player messages

    private func handle(_ message: PlayerBridgeMessage) {
        switch message {
        case .userInteraction:
            showChrome()
        case .sourceUnavailable:
            withAnimation(.easeOut(duration: 0.2)) {
                isSourceUnavailable = true
            }
        case .progress(let event):
            handleProgress(event)
        }
    }

    private func handleProgress(_ event: PlayerProgressEvent) {
        // Only act on events for the title we launched (ignore unrelated frames).
        guard event.id.isEmpty || event.id == item.tmdbId else { return }

        if item.type == .tv {
            playingSeason = event.season ?? playingSeason
            playingEpisode = event.episode ?? playingEpisode
        }

        guard let continueWatchingManager else { return }

        // A finished movie leaves the Continue Watching rail. Series keep their entry so
        // autoplay can carry on to the next episode.
        if item.type == .movie,
           event.kind == .ended || event.fraction >= Self.completionFraction {
            continueWatchingManager.markFinished(type: item.type, tmdbId: item.tmdbId)
            return
        }

        // Discrete events (pause, seek, end) always persist; the continuous tick stream is
        // throttled to every few seconds.
        let isTick = event.kind == .timeUpdate || event.kind == .progress
        if isTick, abs(event.currentTime - lastPersistedSeconds) < Self.persistThreshold {
            return
        }
        guard event.currentTime > 0 else { return }
        lastPersistedSeconds = event.currentTime

        let season = event.season ?? playingSeason ?? item.season
        let episode = event.episode ?? playingEpisode ?? item.episode
        let matchesLaunchedEpisode = season == item.season && episode == item.episode

        continueWatchingManager.recordProgress(
            type: item.type,
            tmdbId: item.tmdbId,
            title: item.title,
            posterPath: item.posterPath,
            season: season,
            episode: episode,
            episodeName: matchesLaunchedEpisode ? item.episodeName : nil,
            positionSeconds: event.currentTime,
            durationSeconds: event.duration
        )
    }

    // MARK: - Audio session

    /// Lets the stream play with sound even when the ring/silent switch is on.
    private static func activatePlaybackAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    private static func deactivatePlaybackAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// A thin spinning ring in the accent colour, used while the player boots.
struct NFLoadingRing: View {
    var color: Color
    var lineWidth: CGFloat = 4

    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0.08, to: 0.78)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
            .accessibilityLabel("Loading")
    }
}

#Preview {
    PlayerView(
        item: WatchItem(
            type: .movie,
            title: "Sample Movie",
            tmdbId: "533535",
            generatedURL: URL(string: "https://vidfast.vc/movie/533535?autoPlay=true")!
        )
    )
}
