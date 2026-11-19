import SwiftUI

/// New & Hot: Coming Soon (with release reminders), Everyone's Watching and today's Top
/// 10s, with jump chips that track the section you're scrolling through.
struct NFNewHotView: View {
    let scrollToTopToken: Int

    fileprivate enum Section: String, CaseIterable, Identifiable {
        case comingSoon
        case everyone
        case topSeries
        case topFilms

        var id: String { rawValue }

        var title: String {
            switch self {
            case .comingSoon: return "Coming Soon"
            case .everyone: return "Everyone's Watching"
            case .topSeries: return "Top 10 Series"
            case .topFilms: return "Top 10 Films"
            }
        }

        var systemImage: String {
            switch self {
            case .comingSoon: return "calendar"
            case .everyone: return "flame.fill"
            case .topSeries, .topFilms: return "10.square.fill"
            }
        }
    }

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router

    /// The section at the top of the list; set it to jump, and it follows scrolling.
    @State private var scrolledSection: String?
    @State private var alertMessage: String?

    private var activeSection: Section {
        scrolledSection.flatMap(Section.init(rawValue:)) ?? availableSections.first ?? .comingSoon
    }

    private var model: NFNewHotModel { app.newHot }

    var body: some View {
        VStack(spacing: 0) {
            header

            chips
                .padding(.vertical, 8)

            if availableSections.isEmpty {
                ScrollView {
                    if model.didFail {
                        failure
                    } else {
                        loadingPlaceholder
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(availableSections) { section in
                            sectionBlock(section)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .scrollPosition(id: $scrolledSection, anchor: .top)
                .onChange(of: scrollToTopToken) { _, _ in
                    if let first = availableSections.first {
                        scroll(to: first)
                    }
                }
            }
        }
        .background(NF.canvas)
        .task {
            await model.loadIfNeeded()
        }
        .alert(
            "Notifications are off",
            isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
        ) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: Header & chips

    private var header: some View {
        HStack {
            Text("New & Hot")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                router.openSearch()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search")
        }
        .padding(.leading, NF.gutter)
        .padding(.trailing, 8)
        .frame(height: 52)
    }

    private var chips: some View {
        ScrollViewReader { chipScroller in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Section.allCases) { section in
                        Button {
                            HapticManager.shared.selection()
                            scroll(to: section)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: section.systemImage)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(section.title)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(activeSection == section ? Color.black : Color.white)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(activeSection == section ? Color.white : Color.white.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(!availableSections.contains(section))
                        .id(section)
                    }
                }
                .padding(.horizontal, NF.gutter)
            }
            .scrollIndicators(.hidden)
            .onChange(of: activeSection) { _, section in
                withAnimation(.easeInOut(duration: 0.25)) {
                    chipScroller.scrollTo(section, anchor: .center)
                }
            }
        }
    }

    /// Scrolls a section to the top. The position is cleared first because assigning
    /// the value it already holds (e.g. re-tapping the current chip) doesn't scroll.
    private func scroll(to section: Section) {
        scrolledSection = nil
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.4)) {
                scrolledSection = section.id
            }
        }
    }

    // MARK: Sections

    private var availableSections: [Section] {
        Section.allCases.filter { section in
            switch section {
            case .comingSoon: return !model.comingSoon.isEmpty
            case .everyone: return !model.everyonesWatching.isEmpty
            case .topSeries: return !model.topSeries.isEmpty
            case .topFilms: return !model.topFilms.isEmpty
            }
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: Section) -> some View {
        LazyVStack(alignment: .leading, spacing: 34) {
            sectionHeader(section)

            switch section {
            case .comingSoon:
                ForEach(model.comingSoon) { upcoming in
                    NFUpcomingRow(upcoming: upcoming, onReminderDenied: {
                        alertMessage = "Allow notifications for Nightflix in Settings to get a reminder when titles come out."
                    })
                }
            case .everyone:
                ForEach(model.everyonesWatching, id: \.nfKey) { item in
                    NFFeatureRow(item: item, rank: nil)
                }
            case .topSeries:
                ForEach(Array(model.topSeries.enumerated()), id: \.element.nfKey) { index, item in
                    NFFeatureRow(item: item, rank: index + 1)
                }
            case .topFilms:
                ForEach(Array(model.topFilms.enumerated()), id: \.element.nfKey) { index, item in
                    NFFeatureRow(item: item, rank: index + 1)
                }
            }
        }
        .padding(.bottom, 34)
    }

    private func sectionHeader(_ section: Section) -> some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Text(section.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, NF.gutter)
        .padding(.top, 14)
        .padding(.bottom, -18)
        .accessibilityAddTraits(.isHeader)
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonView(cornerRadius: 6)
                        .aspectRatio(16 / 9, contentMode: .fit)
                    TextLineSkeletonView(width: 180, height: 14)
                    TextLineSkeletonView(height: 10)
                    TextLineSkeletonView(width: 220, height: 10)
                }
                .padding(.leading, 58)
                .padding(.trailing, NF.gutter)
            }
        }
        .padding(.top, 20)
    }

    private var failure: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(NF.textTertiary)
            Text("New & Hot didn't load.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Button {
                Task { await model.reload() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 20)
                    .frame(height: 38)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: NF.buttonCorner))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}

// MARK: - Coming Soon row

private struct NFUpcomingRow: View {
    let upcoming: NFNewHotModel.Upcoming
    let onReminderDenied: () -> Void

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router

    private var item: MediaItem { upcoming.item }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(spacing: 0) {
                Text(upcoming.date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NF.textSecondary)
                Text(upcoming.date.formatted(.dateTime.day()))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 52)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 12) {
                NFWideArtwork(item: item)
                    .onTapGesture {
                        router.preview(item)
                    }

                HStack(alignment: .center, spacing: 4) {
                    NFTitleLogo(item: item, maxWidth: 160, maxHeight: 46, alignment: .leading, fallbackSize: 20)

                    Spacer(minLength: 8)

                    Button {
                        toggleReminder()
                    } label: {
                        NFIconActionLabel(
                            title: hasReminder ? "Reminder Set" : "Remind Me",
                            systemImage: hasReminder ? "bell.badge.fill" : "bell"
                        )
                    }
                    .buttonStyle(NFPressableStyle(scale: 0.92))

                    Button {
                        router.openTitle(item)
                    } label: {
                        NFIconActionLabel(title: "Info", systemImage: "info.circle")
                    }
                    .buttonStyle(NFPressableStyle(scale: 0.92))
                }

                Text(comingText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(item.overview)
                    .font(.system(size: 13.5))
                    .foregroundStyle(NF.textSecondary)
                    .lineSpacing(1.5)
                    .lineLimit(3)

                if !item.nfGenreTags.isEmpty {
                    Text(item.nfGenreTags.joined(separator: "  •  "))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(.trailing, NF.gutter)
        }
    }

    private var hasReminder: Bool {
        app.library.hasReminder(item)
    }

    private var comingText: String {
        upcoming.date.nfComingLabel(isMovie: item.isMovie)
    }

    private func toggleReminder() {
        HapticManager.shared.selection()
        Task {
            let result = await app.library.toggleReminder(item, releaseDate: upcoming.date)
            switch result {
            case .added:
                HapticManager.shared.success()
            case .removed:
                break
            case .notificationsDenied:
                HapticManager.shared.warning()
                onReminderDenied()
            }
        }
    }
}

// MARK: - Everyone's Watching / Top 10 row

private struct NFFeatureRow: View {
    let item: MediaItem
    let rank: Int?

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @EnvironmentObject private var myList: MyListManager

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if let rank {
                Text("\(rank)")
                    .font(.system(size: 34, weight: .heavy).width(.condensed))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 52)
                    .padding(.top, 2)
                    .accessibilityLabel("Number \(rank)")
            }

            VStack(alignment: .leading, spacing: 12) {
                NFWideArtwork(item: item)
                    .onTapGesture {
                        router.preview(item)
                    }

                HStack(alignment: .center, spacing: 4) {
                    NFTitleLogo(item: item, maxWidth: 160, maxHeight: 46, alignment: .leading, fallbackSize: 20)

                    Spacer(minLength: 8)

                    Button {
                        HapticManager.shared.success()
                        myList.toggle(MyListItem(item))
                    } label: {
                        NFIconActionLabel(title: "My List", systemImage: isInMyList ? "checkmark" : "plus")
                    }
                    .buttonStyle(NFPressableStyle(scale: 0.92))

                    Button {
                        app.play(item, router: router)
                    } label: {
                        NFIconActionLabel(title: "Play", systemImage: "play.fill")
                    }
                    .buttonStyle(NFPressableStyle(scale: 0.92))
                }

                Text(item.overview)
                    .font(.system(size: 13.5))
                    .foregroundStyle(NF.textSecondary)
                    .lineSpacing(1.5)
                    .lineLimit(3)

                if !item.nfGenreTags.isEmpty {
                    Text(item.nfGenreTags.joined(separator: "  •  "))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .padding(.leading, rank == nil ? NF.gutter : 0)
            .padding(.trailing, NF.gutter)
        }
    }

    private var isInMyList: Bool {
        myList.contains(mediaType: item.isMovie ? .movie : .tv, tmdbId: item.id)
    }
}

/// 16:9 key art (textless where TMDB has it) for the New & Hot cards.
private struct NFWideArtwork: View {
    let item: MediaItem

    @Environment(NFAppModel.self) private var app

    var body: some View {
        let path = item.backdropPath
            ?? app.library.artwork.artwork(for: item)?.textlessBackdropPath
            ?? item.posterPath

        Color.clear
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay {
                NFImage(url: NF.imageURL(path, .backdrop))
            }
            .clipShape(RoundedRectangle(cornerRadius: NF.cardCorner, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: NF.cardCorner, style: .continuous))
            .accessibilityLabel(item.displayTitle)
            .accessibilityAddTraits(.isButton)
    }
}
