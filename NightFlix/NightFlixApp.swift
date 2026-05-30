import SwiftUI

@main
struct NightFlixApp: App {
    @StateObject private var settings = AppSettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
