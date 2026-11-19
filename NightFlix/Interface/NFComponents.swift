import SafariServices
import SwiftUI

// MARK: - Title logo

/// The title's logo artwork (TMDB "logos"), sized to fit a box, or the title set in the
/// display face when no logo exists. While the lookup runs, the box is held empty so
/// the layout doesn't jump.
struct NFTitleLogo: View {
    let item: MediaItem
    var maxWidth: CGFloat
    var maxHeight: CGFloat
    var alignment: HorizontalAlignment = .center
    var fallbackSize: CGFloat = 30

    @Environment(NFAppModel.self) private var app

    var body: some View {
        let artwork = app.library.artwork.artwork(for: item)

        Group {
            if let artwork {
                if let logoPath = artwork.logoPath {
                    logo(path: logoPath, aspect: artwork.logoAspectRatio)
                } else {
                    fallbackTitle
                }
            } else {
                Color.clear
                    .frame(width: maxWidth * 0.6, height: maxHeight * 0.7)
            }
        }
        .frame(maxWidth: maxWidth, alignment: Alignment(horizontal: alignment, vertical: .center))
        .task(id: item.nfKey) {
            await app.library.artwork.load(item)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayTitle)
        .accessibilityAddTraits(.isHeader)
    }

    private func logo(path: String, aspect: Double?) -> some View {
        let ratio = max(CGFloat(aspect ?? 2.5), 0.6)
        let width = min(maxWidth, maxHeight * ratio)
        let height = width / ratio

        return NFImage(
            url: NF.imageURL(path, .logo),
            contentMode: .fit,
            placeholder: .none
        )
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.45), radius: 8, y: 2)
    }

    private var fallbackTitle: some View {
        Text(item.displayTitle)
            .font(NF.display(fallbackSize))
            .foregroundStyle(.white)
            .multilineTextAlignment(alignment == .leading ? .leading : .center)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
    }
}

// MARK: - Posters

enum NFPosterBadge {
    case top10
    case newEpisodes
    case newRelease
    case comingSoon

    var label: String? {
        switch self {
        case .top10: return nil
        case .newEpisodes: return "New Episodes"
        case .newRelease: return "Recently Added"
        case .comingSoon: return "Coming Soon"
        }
    }
}

struct NFPosterArtwork: View {
    let item: MediaItem
    var width: CGFloat
    var badges: [NFPosterBadge] = []

    @Environment(\.nightflixAccent) private var accent

    var body: some View {
        NFImage(url: NF.imageURL(item.posterPath, .poster))
            .frame(width: width, height: width * 1.5)
            .overlay(alignment: .topTrailing) {
                if badges.contains(.top10) {
                    NFTop10CornerBadge()
                        .scaleEffect(min(width / 110, 1.2), anchor: .topTrailing)
                }
            }
            .overlay(alignment: .bottom) {
                if let label = badges.compactMap(\.label).first {
                    Text(label)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(accent, in: RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .padding(.bottom, 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: NF.posterCorner, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A poster that opens the quick preview on tap, with a long-press menu.
struct NFPosterButton: View {
    let item: MediaItem
    var width: CGFloat
    var badges: [NFPosterBadge] = []
    var action: ((MediaItem) -> Void)?

    @Environment(NFRouter.self) private var router
    @Environment(NFAppModel.self) private var app
    @EnvironmentObject private var myList: MyListManager

    var body: some View {
        Button {
            if let action {
                action(item)
            } else {
                router.preview(item)
            }
        } label: {
            NFPosterArtwork(item: item, width: width, badges: badges)
        }
        .buttonStyle(NFPressableStyle())
        .accessibilityLabel(item.displayTitle)
        .contextMenu {
            Button {
                app.play(item, router: router)
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                toggleMyList()
            } label: {
                if isInMyList {
                    Label("Remove from My List", systemImage: "checkmark")
                } else {
                    Label("Add to My List", systemImage: "plus")
                }
            }

            Button {
                router.openTitle(item)
            } label: {
                Label("Details & More", systemImage: "info.circle")
            }
        } preview: {
            NFPosterContextPreview(item: item)
                .environment(app)
        }
    }

    private var isInMyList: Bool {
        myList.contains(mediaType: item.isMovie ? .movie : .tv, tmdbId: item.id)
    }

    private func toggleMyList() {
        HapticManager.shared.success()
        myList.toggle(MyListItem(item))
    }
}

/// Larger card shown while long-pressing a poster.
private struct NFPosterContextPreview: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NFImage(url: NF.imageURL(item.backdropPath ?? item.posterPath, .backdrop))
                .frame(width: 320, height: 180)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(NFMeta.line(for: item))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NF.textSecondary)

                if !item.overview.isEmpty {
                    Text(item.overview)
                        .font(.system(size: 13))
                        .foregroundStyle(NF.textSecondary)
                        .lineLimit(3)
                }
            }
            .padding(14)
        }
        .frame(width: 320, alignment: .leading)
        .background(NF.surface)
    }
}

/// The small "TOP 10" flag in a poster's top-right corner.
struct NFTop10CornerBadge: View {
    @Environment(\.nightflixAccent) private var accent

    var body: some View {
        VStack(spacing: -2) {
            Text("TOP")
                .font(.system(size: 6.5, weight: .heavy))
                .kerning(0.4)
            Text("10")
                .font(.system(size: 12, weight: .black))
        }
        .foregroundStyle(.white)
        .frame(width: 20, height: 26)
        .background(accent, in: UnevenRoundedRectangle(bottomLeadingRadius: 2))
    }
}

/// The big outlined rank numeral beside a Top 10 poster.
struct NFRankNumeral: View {
    let rank: Int
    let height: CGFloat

    private static let outline: [CGSize] = {
        let radius: CGFloat = 1.6
        return stride(from: 0.0, to: 360.0, by: 45.0).map { degrees in
            let radians = degrees * .pi / 180
            return CGSize(width: cos(radians) * radius, height: sin(radians) * radius)
        }
    }()

    var body: some View {
        let text = Text("\(rank)")
            .font(.system(size: height * 0.98, weight: .heavy).width(.condensed))
            .kerning(rank >= 10 ? -height * 0.12 : 0)

        ZStack {
            ForEach(Array(Self.outline.enumerated()), id: \.offset) { _, offset in
                text
                    .foregroundStyle(Color(white: 0.5))
                    .offset(offset)
            }

            text.foregroundStyle(Color.black)
        }
        .lineLimit(1)
        .fixedSize()
        .frame(height: height, alignment: .bottom)
        .offset(y: height * 0.11)
        .accessibilityHidden(true)
    }
}

struct NFTop10Card: View {
    let rank: Int
    let item: MediaItem
    let posterWidth: CGFloat

    var body: some View {
        HStack(alignment: .bottom, spacing: rank >= 10 ? -posterWidth * 0.2 : -posterWidth * 0.17) {
            NFRankNumeral(rank: rank, height: posterWidth * 1.5)
            NFPosterButton(item: item, width: posterWidth)
        }
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Number \(rank), \(item.displayTitle)")
    }
}

// MARK: - Continue Watching

/// Portrait card with a play glyph, a progress bar and an info/more footer.
struct NFContinueCard: View {
    let entry: ContinueWatchingItem
    let width: CGFloat
    let onPlay: () -> Void
    let onInfo: () -> Void
    let onRemove: () -> Void

    @Environment(\.nightflixAccent) private var accent

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onPlay) {
                ZStack(alignment: .bottom) {
                    NFImage(url: entry.posterURL ?? NF.imageURL(entry.posterPath, .poster))
                        .frame(width: width, height: width * 1.42)

                    Image(systemName: "play.fill")
                        .font(.system(size: width * 0.16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: width * 0.42, height: width * 0.42)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .overlay {
                            Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    NFProgressBar(fraction: entry.progressFraction ?? 0.02, tint: accent, height: 3)
                }
                .frame(width: width, height: width * 1.42)
                .contentShape(Rectangle())
            }
            .buttonStyle(NFPressableStyle(scale: 0.98))
            .accessibilityLabel("Resume \(entry.title)")

            HStack(spacing: 0) {
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .regular))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Details for \(entry.title)")

                Spacer(minLength: 0)

                if let label = footerLabel {
                    Text(label)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(NF.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)

                Menu {
                    Button(action: onInfo) {
                        Label("Details & More", systemImage: "info.circle")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove from Row", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .rotationEffect(.degrees(90))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More options")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(width: width, height: 34)
            .background(Color(white: 0.13))
        }
        .clipShape(RoundedRectangle(cornerRadius: NF.posterCorner, style: .continuous))
    }

    private var footerLabel: String? {
        if entry.type == .tv, let season = entry.season, let episode = entry.episode {
            return "S\(season):E\(episode)"
        }

        if let progress = entry.progressSeconds, let duration = entry.durationSeconds, duration > 0 {
            return NF.compactDuration(seconds: duration - progress)
        }

        return nil
    }
}

// MARK: - Small pieces

struct NFProgressBar: View {
    let fraction: Double
    var tint: Color
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.28))
                Rectangle()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("\(Int((fraction * 100).rounded()))% watched")
    }
}

struct NFRowHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, NF.gutter)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Outlined filter chip ("Series", "Films", "Categories ▾").
struct NFChip: View {
    let title: String
    var systemImage: String?
    var trailingSystemImage: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                }

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(isSelected ? Color.white.opacity(0.22) : Color.clear, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.55), lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Round "clear filters" chip.
struct NFClearChip: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear filters")
    }
}

/// Boxed maturity rating ("PG-13", "TV-MA").
struct NFCertificationBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NF.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(NF.textTertiary, lineWidth: 1)
            }
    }
}

/// A row of grey placeholder posters while a rail loads.
struct NFPosterRowSkeleton: View {
    let width: CGFloat
    var count = 6

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonView(cornerRadius: NF.posterCorner)
                    .frame(width: width, height: width * 1.5)
            }
        }
        .padding(.horizontal, NF.gutter)
        .accessibilityLabel("Loading")
    }
}

// MARK: - Full-screen option picker

/// The centred, blurred list used for categories and seasons, with a round close
/// button at the bottom.
struct NFPickerOverlay: View {
    let request: NFPickerRequest
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.62))
                .ignoresSafeArea()
                .onTapGesture { close() }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 26) {
                        ForEach(request.options) { option in
                            Button {
                                HapticManager.shared.selection()
                                request.onSelect(option.id)
                                close()
                            } label: {
                                Text(option.title)
                                    .font(.system(size: option.id == request.selectedID ? 21 : 18,
                                                  weight: option.id == request.selectedID ? .bold : .medium))
                                    .foregroundStyle(option.id == request.selectedID ? Color.white : NF.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(option.id)
                        }
                    }
                    .padding(.top, 90)
                    .padding(.bottom, 160)
                }
                .scrollIndicators(.hidden)
                .mask {
                    // Fade the list out at the edges so it slides under the close button.
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.1),
                            .init(color: .black, location: 0.72),
                            .init(color: .clear, location: 0.86)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .onAppear {
                    if let selected = request.selectedID {
                        proxy.scrollTo(selected, anchor: .center)
                    }
                }
            }

            VStack {
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 58, height: 58)
                        .background(Color.white, in: Circle())
                        .shadow(color: .black.opacity(0.4), radius: 14, y: 6)
                }
                .buttonStyle(NFPressableStyle(scale: 0.92))
                .accessibilityLabel("Close")
                .padding(.bottom, 28)
            }
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 1.04)
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) {
                isVisible = true
            }
        }
    }

    private func close() {
        HapticManager.shared.lightImpact()
        withAnimation(.easeIn(duration: 0.16)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            onDismiss()
        }
    }
}

// MARK: - Meta formatting

enum NFMeta {
    /// "2024 · Series · Drama, Comedy" style line for list items.
    static func line(for item: MediaItem) -> String {
        var parts: [String] = []
        if let year = item.displayYear, !year.isEmpty { parts.append(year) }
        parts.append(item.isMovie ? "Film" : "Series")
        let tags = item.nfGenreTags.prefix(2)
        if !tags.isEmpty { parts.append(tags.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - My List bridging

extension MyListItem {
    init(_ item: MediaItem) {
        self.init(
            mediaType: item.isMovie ? .movie : .tv,
            tmdbId: item.id,
            title: item.displayTitle,
            posterPath: item.posterPath,
            backdropPath: item.backdropPath,
            overview: item.overview,
            year: item.displayYear,
            dateAdded: Date()
        )
    }
}

// MARK: - Safari (trailers)

struct NFSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = .white
        controller.preferredBarTintColor = .black
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

struct NFIdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Reminders

/// "Remind Me" for titles that aren't out yet: schedules a local notification for
/// release day, and explains how to allow notifications if they're off.
struct NFReminderButton: View {
    enum Style {
        case primary(height: CGFloat)
        case icon
    }

    let item: MediaItem
    let date: Date
    var style: Style = .primary(height: 42)

    @Environment(NFAppModel.self) private var app
    @State private var isShowingDeniedAlert = false

    var body: some View {
        Button {
            toggle()
        } label: {
            switch style {
            case .primary(let height):
                NFPrimaryButtonLabel(
                    title: isSet ? "Reminder Set" : "Remind Me",
                    systemImage: isSet ? "bell.badge.fill" : "bell.fill",
                    height: height
                )
            case .icon:
                NFIconActionLabel(
                    title: isSet ? "Reminder Set" : "Remind Me",
                    systemImage: isSet ? "bell.badge.fill" : "bell"
                )
            }
        }
        .buttonStyle(NFPressableStyle())
        .alert("Notifications are off", isPresented: $isShowingDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Allow notifications for Nightflix in Settings to get a reminder when \(item.displayTitle) comes out.")
        }
    }

    private var isSet: Bool {
        app.library.hasReminder(item)
    }

    private func toggle() {
        HapticManager.shared.selection()
        Task {
            switch await app.library.toggleReminder(item, releaseDate: date) {
            case .added:
                HapticManager.shared.success()
            case .removed:
                break
            case .notificationsDenied:
                HapticManager.shared.warning()
                isShowingDeniedAlert = true
            }
        }
    }
}

extension Date {
    /// "Coming December 18" / "Premieres Friday" style label for unreleased titles.
    func nfComingLabel(isMovie: Bool) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: self).day ?? 0
        let verb = isMovie ? "Coming" : "Premieres"

        if days <= 1 { return "\(verb) Tomorrow" }
        if days < 7 { return "\(verb) \(formatted(.dateTime.weekday(.wide)))" }

        let sameYear = calendar.component(.year, from: self) == calendar.component(.year, from: Date())
        return sameYear
            ? "\(verb) \(formatted(.dateTime.month(.wide).day()))"
            : "\(verb) \(formatted(.dateTime.month(.wide).day().year()))"
    }
}
