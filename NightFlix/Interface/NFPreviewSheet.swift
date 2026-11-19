import SwiftUI

/// Derived, display-ready facts about a title from its list item and (once loaded)
/// its full payload.
struct NFTitleFacts {
    let item: MediaItem
    let payload: NFTitlePayload?

    var title: String {
        payload?.title ?? payload?.name ?? item.displayTitle
    }

    var overview: String {
        let text = payload?.overview ?? ""
        return text.isEmpty ? item.overview : text
    }

    var year: String? {
        let date = payload?.releaseDate ?? payload?.firstAirDate ?? (item.isMovie ? item.releaseDate : item.firstAirDate)
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var certification: String? {
        if item.isMovie {
            let countries = (payload?.releaseDates?.results ?? []).compactMap(\.value)
            let preferred = countries.first { $0.country == "US" } ?? countries.first { $0.country == "GB" }
            return preferred?.releaseDates?
                .compactMap { $0.value?.certification }
                .first { !$0.isEmpty }
        }

        let ratings = (payload?.contentRatings?.results ?? []).compactMap(\.value)
        let preferred = ratings.first { $0.country == "US" } ?? ratings.first { $0.country == "GB" }
        guard let rating = preferred?.rating, !rating.isEmpty else { return nil }
        return rating
    }

    /// "2h 13m" for films, "3 Seasons" / "8 Episodes" for series.
    var lengthText: String? {
        if item.isMovie {
            return NF.runtimeText(minutes: payload?.runtime)
        }

        guard let seasons = playableSeasons.count > 0 ? playableSeasons.count : payload?.numberOfSeasons else {
            return nil
        }
        return seasons == 1 ? "1 Season" : "\(seasons) Seasons"
    }

    var releaseDate: Date? {
        NF.date(fromTMDB: payload?.releaseDate ?? payload?.firstAirDate)
            ?? item.releaseDateValue
    }

    /// The release / premiere date when it's still in the future.
    var upcomingDate: Date? {
        guard let releaseDate, releaseDate > Date() else { return nil }
        return releaseDate
    }

    var scorePercent: Int? {
        NF.scorePercent(payload?.voteAverage ?? item.voteAverage)
    }

    var genres: [String] {
        let names = (payload?.genres ?? []).compactMap { $0.value?.name }
        return names.isEmpty ? item.nfGenreTags : Array(names.prefix(3))
    }

    var cast: [NFCastPayload] {
        (payload?.credits?.cast ?? []).compactMap(\.value)
    }

    var castLine: String? {
        let names = cast.prefix(3).map(\.name)
        guard !names.isEmpty else { return nil }
        return names.joined(separator: ", ") + (cast.count > 3 ? ", more" : "")
    }

    var creatorLine: (label: String, names: String)? {
        if item.isMovie {
            let directors = (payload?.credits?.crew ?? [])
                .compactMap(\.value)
                .filter { $0.job == "Director" }
                .map(\.name)
            guard !directors.isEmpty else { return nil }
            return (directors.count == 1 ? "Director" : "Directors", directors.prefix(2).joined(separator: ", "))
        }

        let creators = (payload?.createdBy ?? []).compactMap { $0.value?.name }
        guard !creators.isEmpty else { return nil }
        return (creators.count == 1 ? "Creator" : "Creators", creators.prefix(2).joined(separator: ", "))
    }

    var videos: [NFVideoPayload] {
        (payload?.videos?.results ?? [])
            .compactMap(\.value)
            .filter(\.isYouTube)
            .sorted { lhs, rhs in
                rank(lhs) > rank(rhs)
            }
    }

    var trailer: NFVideoPayload? {
        videos.first { $0.type == "Trailer" } ?? videos.first { $0.type == "Teaser" }
    }

    var playableSeasons: [NFSeasonSummary] {
        let all = (payload?.seasons ?? []).compactMap(\.value).filter { ($0.episodeCount ?? 1) > 0 }
        let regular = all.filter { $0.seasonNumber > 0 }
        return regular.isEmpty ? all : regular
    }

    var moreLikeThis: [MediaItem] {
        let fallback = item.nfType
        let recommended = (payload?.recommendations?.results ?? []).compactMap { $0.value?.mediaItem(fallback: fallback) }
        let similar = (payload?.similar?.results ?? []).compactMap { $0.value?.mediaItem(fallback: fallback) }

        var seen: Set<String> = [item.nfKey]
        return (recommended + similar).filter { $0.isBrowsable && seen.insert($0.nfKey).inserted }
    }

    var artwork: NFArtwork? {
        payload?.images.map { NFArtwork(images: $0) }
    }

    private func rank(_ video: NFVideoPayload) -> Int {
        var score = 0
        if video.type == "Trailer" { score += 4 }
        if video.official == true { score += 2 }
        if video.language == "en" { score += 1 }
        return score
    }
}

/// Netflix-style quick preview: poster, essentials, Play / My List / Share and a link to
/// the full title page. Sized to fit its content.
struct NFPreviewSheet: View {
    let item: MediaItem

    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router
    @EnvironmentObject private var myList: MyListManager

    @State private var payload: NFTitlePayload?
    @State private var contentHeight: CGFloat = 320

    private var facts: NFTitleFacts {
        NFTitleFacts(item: item, payload: payload)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 18)

            actions
                .padding(.top, 18)

            Rectangle()
                .fill(NF.hairline)
                .frame(height: 1)
                .padding(.top, 16)

            detailsLink
        }
        .padding(.horizontal, NF.gutter)
        .padding(.bottom, 6)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            contentHeight = height
        }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(18)
        .presentationBackground(NF.surface)
        .preferredColorScheme(.dark)
        .task(id: item.nfKey) {
            payload = try? await NFCatalogService.title(type: item.nfType, id: item.id)
            if let artwork = facts.artwork {
                app.library.artwork.store(artwork, for: item)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                router.openTitle(item)
            } label: {
                NFPosterArtwork(item: item, width: 102)
            }
            .buttonStyle(NFPressableStyle())

            VStack(alignment: .leading, spacing: 7) {
                Text(facts.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.trailing, 34)
                    .fixedSize(horizontal: false, vertical: true)

                NFTitleMetaRow(facts: facts, compact: true)

                Text(facts.overview.isEmpty ? "No synopsis available yet." : facts.overview)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(1.5)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticManager.shared.lightImpact()
                router.dismissSheet()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.16), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var actions: some View {
        HStack(alignment: .center, spacing: 6) {
            Group {
                if let date = facts.upcomingDate {
                    NFReminderButton(item: item, date: date, style: .primary(height: 38))
                } else {
                    Button {
                        app.play(item, router: router)
                    } label: {
                        NFPrimaryButtonLabel(title: playTitle, height: 38)
                    }
                    .buttonStyle(NFPressableStyle())
                }
            }
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            Button {
                HapticManager.shared.success()
                myList.toggle(MyListItem(item))
            } label: {
                NFIconActionLabel(title: "My List", systemImage: isInMyList ? "checkmark" : "plus")
            }
            .buttonStyle(NFPressableStyle())

            if let url = item.tmdbWebURL {
                ShareLink(item: url, subject: Text(facts.title), message: Text("Watch \(facts.title) on Nightflix")) {
                    NFIconActionLabel(title: "Share", systemImage: "paperplane")
                }
                .buttonStyle(NFPressableStyle())
            }
        }
    }

    private var detailsLink: some View {
        Button {
            router.openTitle(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .font(.system(size: 17))
                Text(item.isMovie ? "Details & More" : "Episodes & Info")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NF.textTertiary)
            }
            .foregroundStyle(.white)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var playTitle: String {
        guard let resume = app.resumeState(for: item), resume.hasProgress else { return "Play" }
        return "Resume"
    }

    private var isInMyList: Bool {
        myList.contains(mediaType: item.isMovie ? .movie : .tv, tmdbId: item.id)
    }
}

/// "2024  [PG-13]  2h 13m  87%" — the compact facts line under a title.
struct NFTitleMetaRow: View {
    let facts: NFTitleFacts
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            if let score = facts.scorePercent, !compact {
                Text("\(score)% rating")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NF.positive)
            }

            if let year = facts.year {
                Text(year)
            }

            if let certification = facts.certification {
                NFCertificationBadge(text: certification)
            }

            if let length = facts.lengthText {
                Text(length)
            }

            if let score = facts.scorePercent, compact {
                Text("\(score)%")
                    .foregroundStyle(NF.positive)
            }
        }
        .font(.system(size: compact ? 12.5 : 13.5, weight: .medium))
        .foregroundStyle(NF.textSecondary)
        .lineLimit(1)
    }
}
