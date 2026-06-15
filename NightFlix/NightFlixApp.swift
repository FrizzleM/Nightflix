//
//  NightFlixApp.swift
//  NightFlix
//
//  Created by Tommaso d’Addio on 24/05/2026.
//

import SwiftUI

@main
struct NightFlixApp: App {
    @StateObject private var settings = AppSettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environment(\.nightflixAccent, settings.accentColor)
                .tint(settings.accentColor)
                .preferredColorScheme(settings.preferredColorScheme)
        }
    }
}
