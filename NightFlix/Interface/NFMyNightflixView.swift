import SwiftUI

/// "My Nightflix": the personal tab — progress, My List, rated titles, reminders and
/// recently watched, plus the entry point to Settings.
struct NFMyNightflixView: View {
    let scrollToTopToken: Int

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @Environment(\.nightflixAccent) private var accent
    @EnvironmentObject private var myList: MyListManager

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollViewReader { scroller in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            Color.clear.frame(height: 0).id("top")

                            profile

                            if isEmpty {
                                emptyState
                            } else {
                                content(width: proxy.size.width)
                            }

                            settingsRow
                        }
                        .padding(.bottom, 30)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: scrollToTopToken) { _, _ in
                        withAnimation(.easeInOut(duration: 0.35)) {
                            scroller.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .background(NF.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: NFMyListDestination.self) { _ in
                NFMyListGrid()
            }
        }
    }

    private var isEmpty: Bool {
        app.continueWatching.items.isEmpty
            && myList.items.isEmpty
            && app.library.liked.isEmpty
            && app.library.reminders.isEmpty
            && app.history.items.isEmpty
    }

    // MARK: Header & profile

    private var header: some View {
        HStack(spacing: 6) {
            Text("My Nightflix")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                router.openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search")

            Button {
                router.openSettings()
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Settings")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.leading, NF.gutter)
        .padding(.trailing, 8)
        .frame(height: 52)
        .background(NF.canvas.opacity(0.96).ignoresSafeArea(edges: .top))
    }

    private var profile: some View {
        VStack(spacing: 12) {
            NFProfileAvatar(size: 72)

            VStack(spacing: 4) {
                Text("Your Nightflix")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                Text(statsLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(NF.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    private var statsLine: String {
        let saved = myList.items.count
        let inProgress = app.continueWatching.items.count
        return "\(saved) in My List · \(inProgress) in progress"
    }

    // MARK: Sections

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        let posterWidth = NF.posterWidth(for: width)

        if !app.continueWatching.items.isEmpty {
            section("Continue Watching") {
                rail {
                    ForEach(app.continueWatching.items) { entry in
                        NFContinueCard(
                            entry: entry,
                            width: posterWidth,
                            onPlay: { resume(entry) },
                            onInfo: { router.preview(media(for: entry)) },
                            onRemove: {
                                withAnimation(.snappy) {
                                    app.continueWatching.markFinished(type: entry.type, tmdbId: entry.tmdbId)
                                }
                            }
                        )
                    }
                }
            }
        }

        section("My List", accessory: myList.items.count > 4 ? AnyView(seeAllLink) : nil) {
            if myList.items.isEmpty {
                Text("Tap + on any title to save it here.")
                    .font(.system(size: 14))
                    .foregroundStyle(NF.textTertiary)
                    .padding(.horizontal, NF.gutter)
            } else {
                rail {
                    ForEach(myList.items) { saved in
                        NFPosterButton(item: saved.mediaItem, width: posterWidth)
                    }
                }
            }
        }

        if !app.library.liked.isEmpty {
            section("Titles You've Rated") {
                rail {
                    ForEach(app.library.liked) { saved in
                        NFPosterButton(item: saved.mediaItem, width: posterWidth)
                    }
                }
            }
        }

        if !app.library.reminders.isEmpty {
            section("Reminders") {
                rail {
                    ForEach(app.library.reminders) { reminder in
                        VStack(alignment: .leading, spacing: 6) {
                            NFPosterButton(item: reminder.title.mediaItem, width: posterWidth)
                            Label(
                                reminder.releaseDate.formatted(.dateTime.month(.abbreviated).day()),
                                systemImage: "bell.fill"
                            )
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(NF.textSecondary)
                        }
                    }
                }
            }
        }

        if !app.history.items.isEmpty {
            section("Recently Watched") {
                VStack(spacing: 14) {
                    ForEach(app.history.items) { entry in
                        historyRow(entry)
                    }
                }
                .padding(.horizontal, NF.gutter)
            }
        }
    }

    private var seeAllLink: some View {
        NavigationLink(value: NFMyListDestination.all) {
            HStack(spacing: 3) {
                Text("See All")
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NF.textSecondary)
        }
    }

    private func section<Content: View>(
        _ title: String,
        accessory: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                accessory
            }
            .padding(.horizontal, NF.gutter)

            content()
        }
    }

    private func rail<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 8) {
                content()
            }
            .padding(.horizontal, NF.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func historyRow(_ entry: WatchItem) -> some View {
        HStack(spacing: 12) {
            Button {
                router.preview(MediaItem.make(
                    id: Int(entry.tmdbId) ?? 0,
                    type: entry.type,
                    title: entry.title,
                    posterPath: entry.posterPath
                ))
            } label: {
                HStack(spacing: 12) {
                    NFImage(url: entry.posterURL ?? NF.imageURL(entry.posterPath, .poster))
                        .frame(width: 52, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(historySubtitle(entry))
                            .font(.system(size: 12.5))
                            .foregroundStyle(NF.textSecondary)
                            .lineLimit(1)

                        Text(entry.dateWatched.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11.5))
                            .foregroundStyle(NF.textTertiary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NFPressableStyle(scale: 0.99))

            Button {
                replay(entry)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .overlay { Circle().strokeBorder(Color.white, lineWidth: 1.5) }
                    .contentShape(Circle())
            }
            .buttonStyle(NFPressableStyle(scale: 0.9))
            .accessibilityLabel("Play \(entry.title)")
        }
    }

    private func historySubtitle(_ entry: WatchItem) -> String {
        guard entry.type == .tv, let season = entry.season, let episode = entry.episode else {
            return "Film"
        }

        if let name = entry.episodeName, !name.isEmpty {
            return "S\(season):E\(episode) · \(name)"
        }
        return "S\(season):E\(episode)"
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles.tv")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(NF.textTertiary)

            Text("Your space is empty for now")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            Text("What you watch, save to My List or rate shows up here.")
                .font(.system(size: 14))
                .foregroundStyle(NF.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 30)
    }

    private var settingsRow: some View {
        Button {
            router.openSettings()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(NF.surfaceRaised, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("App Settings")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Accent colour, haptics, data")
                        .font(.system(size: 12.5))
                        .foregroundStyle(NF.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NF.textTertiary)
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(NF.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(NFPressableStyle(scale: 0.99))
        .padding(.horizontal, NF.gutter)
    }

    // MARK: Playback

    private func media(for entry: ContinueWatchingItem) -> MediaItem {
        MediaItem.make(id: entry.tmdbIntId ?? 0, type: entry.type, title: entry.title, posterPath: entry.posterPath)
    }

    private func resume(_ entry: ContinueWatchingItem) {
        guard let id = entry.tmdbIntId else { return }

        let item: WatchItem?
        switch entry.type {
        case .movie:
            item = app.movieItem(id: id, title: entry.title, posterPath: entry.posterPath)
        case .tv:
            item = app.episodeItem(
                seriesId: id,
                seriesName: entry.title,
                posterPath: entry.posterPath,
                season: entry.season ?? 1,
                episode: entry.episode ?? 1,
                episodeName: entry.episodeName
            )
        }

        guard let item else {
            HapticManager.shared.error()
            return
        }
        app.play(item, router: router)
    }

    private func replay(_ entry: WatchItem) {
        guard let id = Int(entry.tmdbId) else { return }

        let item: WatchItem?
        switch entry.type {
        case .movie:
            item = app.movieItem(id: id, title: entry.title, posterPath: entry.posterPath)
        case .tv:
            item = app.episodeItem(
                seriesId: id,
                seriesName: entry.title,
                posterPath: entry.posterPath,
                season: entry.season ?? 1,
                episode: entry.episode ?? 1,
                episodeName: entry.episodeName
            )
        }

        guard let item else {
            HapticManager.shared.error()
            return
        }
        app.play(item, router: router)
    }
}

enum NFMyListDestination: Hashable {
    case all
}

/// Every saved title as a grid, newest first, with long-press removal.
struct NFMyListGrid: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var myList: MyListManager

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 8
            let columnWidth = ((proxy.size.width - NF.gutter * 2 - spacing * 2) / 3).rounded(.down)

            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(columnWidth), spacing: spacing), count: 3),
                    alignment: .leading,
                    spacing: spacing
                ) {
                    ForEach(myList.items) { saved in
                        NFPosterButton(item: saved.mediaItem, width: columnWidth)
                    }
                }
                .padding(.horizontal, NF.gutter)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    HapticManager.shared.lightImpact()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Text("My List")
                    .font(.system(size: 20, weight: .bold))

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(height: 50)
            .background(NF.canvas.opacity(0.96).ignoresSafeArea(edges: .top))
        }
        .background(NF.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// The profile tile: a rounded square in the accent colour with a friendly face.
struct NFProfileAvatar: View {
    var size: CGFloat
    var isSelected = false

    @Environment(\.nightflixAccent) private var accent

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent, accent.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: size * 0.56, weight: .regular))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: isSelected ? max(size * 0.07, 1.5) : 0)
            }
            .accessibilityHidden(true)
    }
}
