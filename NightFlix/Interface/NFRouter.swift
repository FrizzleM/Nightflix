import Observation
import SwiftUI

/// Presentation state for one level of the app (the tab shell, the search screen, a
/// title page): the quick-preview sheet and one full-screen cover at a time. Each
/// level installs its own router with `.nfRouterHost()`, so a title opened from a
/// title page stacks above it instead of fighting the root for presentation.
@Observable
final class NFRouter {
    enum Sheet: Identifiable {
        case preview(MediaItem)
        case settings

        var id: String {
            switch self {
            case .preview(let item): return "preview-\(item.nfKey)"
            case .settings: return "settings"
            }
        }
    }

    enum Cover: Identifiable {
        case title(MediaItem)
        case player(WatchItem)
        case search

        var id: String {
            switch self {
            case .title(let item): return "title-\(item.nfKey)"
            case .player(let item): return "player-\(item.id.uuidString)"
            case .search: return "search"
            }
        }
    }

    var sheet: Sheet?
    var cover: Cover?
    @ObservationIgnored private var pendingCover: Cover?

    func preview(_ item: MediaItem) {
        guard cover == nil else { return }
        HapticManager.shared.lightImpact()
        sheet = .preview(item)
    }

    func openTitle(_ item: MediaItem) {
        present(.title(item))
    }

    func play(_ item: WatchItem) {
        present(.player(item))
    }

    func openSearch() {
        HapticManager.shared.lightImpact()
        present(.search)
    }

    func openSettings() {
        HapticManager.shared.lightImpact()
        sheet = .settings
    }

    func dismissSheet() {
        sheet = nil
    }

    /// Covers can't present while the sheet is up, so queue them until it's gone.
    private func present(_ next: Cover) {
        if sheet != nil {
            pendingCover = next
            sheet = nil
        } else {
            cover = next
        }
    }

    func sheetDidDismiss() {
        guard let pendingCover else { return }
        self.pendingCover = nil
        cover = pendingCover
    }
}

extension View {
    /// Gives this subtree its own router for previews, title pages, search and the player.
    func nfRouterHost() -> some View {
        modifier(NFRouterHost())
    }
}

private struct NFRouterHost: ViewModifier {
    @Environment(NFAppModel.self) private var app
    @EnvironmentObject private var myList: MyListManager
    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.nightflixAccent) private var accent

    @State private var router = NFRouter()

    func body(content: Content) -> some View {
        @Bindable var router = router

        content
            .environment(router)
            .sheet(item: $router.sheet, onDismiss: router.sheetDidDismiss) { sheet in
                sheetContent(sheet)
                    .environment(app)
                    .environment(router)
                    .environmentObject(myList)
                    .environmentObject(settings)
                    .environment(\.nightflixAccent, accent)
                    .tint(accent)
            }
            .fullScreenCover(item: $router.cover) { cover in
                coverContent(cover)
                    .environment(app)
                    .environmentObject(myList)
                    .environmentObject(settings)
                    .environment(\.nightflixAccent, accent)
                    .tint(accent)
            }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: NFRouter.Sheet) -> some View {
        switch sheet {
        case .preview(let item):
            NFPreviewSheet(item: item)
        case .settings:
            AboutView(
                historyManager: app.history,
                continueWatchingManager: app.continueWatching,
                animationTrigger: 0,
                showNightflixTitle: true,
                shouldAnimateNightflixTitle: false
            )
            .presentationBackground(Color.black)
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func coverContent(_ cover: NFRouter.Cover) -> some View {
        switch cover {
        case .title(let item):
            NFTitleStack(item: item)
        case .player(let item):
            PlayerView(item: item, continueWatchingManager: app.continueWatching)
        case .search:
            NFSearchView()
        }
    }
}

// MARK: - Playback helper

extension NFAppModel {
    /// Builds, records and presents playback for a title (resuming where possible).
    func play(_ media: MediaItem, router: NFRouter) {
        guard let item = watchItem(for: media) else {
            HapticManager.shared.error()
            return
        }

        HapticManager.shared.impactStrong()
        record(item)
        router.play(item)
    }

    func play(_ item: WatchItem, router: NFRouter) {
        HapticManager.shared.impactStrong()
        record(item)
        router.play(item)
    }
}
