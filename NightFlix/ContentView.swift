import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: AppSettingsManager

    var body: some View {
        ZStack {
            if settings.isShutdownInProgress {
                NightFlixStyle.backgroundColor.ignoresSafeArea()
            } else {
                MainTabView()
            }

            if let shutdownCountdown = settings.shutdownCountdown {
                ShutdownCountdownOverlay(secondsRemaining: shutdownCountdown)
                    .transition(.opacity)
                    .zIndex(1001)
            }
        }
        .onAppear {
            settings.updateAutomaticUpdateCheckPreferenceForInstalledVersion()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettingsManager())
}
