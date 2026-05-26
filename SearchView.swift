import SwiftUI

struct SearchView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager

    @State private var searchViewModel = SearchViewModel()
    @State private var selectedItem: WatchItem?
    @State private var selectedSeries: SeriesSelection?
    @State private var selectedDetailItem: MediaItem?
    @State private var playErrorMessage: String?
    @State private var entranceVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                NightFlixStyle.backgroundColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        searchControls
                        searchResultsSection
                    }
                    .padding(20)
                }
            }
            .navigationDestination(item: $selectedItem) { item in
                PlayerView(item: item)
            }
            .navigationDestination(item: $selectedSeries) { series in
                SeriesDetailView(
                    seriesId: series.id,
                    fallbackName: series.name,
                    fallbackPosterPath: series.posterPath,
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager
                )
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                MediaDetailView(
                    item: item,
                    historyManager: historyManager,
                    continueWatchingManager: continueWatchingManager
                )
            }
        }
        .onAppear {
            startEntrance()
        }
        .tint(NightFlixStyle.accentColor)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nightflix")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(NightFlixStyle.accentColor)
                .nightflixTitleGlow()
                .shadow(color: NightFlixStyle.titleGlowColor, radius: 16)
                .shadow(color: NightFlixStyle.titleSecondaryGlowColor, radius: 34)
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.1, yOffset: 14, scaleAmount: 0.98)

            Text("An app by Frizzle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.74))
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.25, yOffset: 12, scaleAmount: 0.98)
        }
    }

    private var searchControls: some View {
        MediaSearchBar(query: searchQueryBinding)
            .padding(18)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NightFlixStyle.borderColor(darkOpacity: 0.08), lineWidth: 1)
            }
            .nightflixEntrance(isVisible: entranceVisible, delay: 0.35, yOffset: 14, scaleAmount: 0.98)
    }

    private var searchResultsSection: some View {
        MediaSearchResultsView(
            title: "Search Results",
            viewModel: searchViewModel,
            playErrorMessage: playErrorMessage,
            isEntranceVisible: entranceVisible,
            baseDelay: 0.42,
            onSelectResult: showDetail
        )
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { searchViewModel.query },
            set: { newValue in
                playErrorMessage = nil
                if searchViewModel.hasActiveQuery && newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    HapticManager.shared.lightImpact()
                }
                searchViewModel.updateQuery(newValue)
            }
        )
    }

    private func startEntrance() {
        guard !entranceVisible else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            entranceVisible = true
        }
    }

    private func cardDelay(_ index: Int, baseDelay: Double) -> Double {
        baseDelay + min(Double(index) * 0.06, 0.42)
    }

    private func showDetail(_ result: MediaSearchResult) {
        playErrorMessage = nil
        HapticManager.shared.mediumImpact()
        selectedDetailItem = result.mediaItem
    }
}

struct MediaSearchBar: View {
    @Binding var query: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.semibold))
                .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.58))

            TextField("Search movies or TV series", text: $query)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .submitLabel(.search)
                .focused($isFocused)

            if !query.isEmpty {
                Button {
                    HapticManager.shared.lightImpact()
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.5, light: .tertiaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .nightFlixSearchBarGlass()
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NightFlixStyle.prominentBorderColor, lineWidth: 1)
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                HapticManager.shared.selection()
                HapticManager.shared.prepareImpact(style: .light)
            } else {
                HapticManager.shared.prepareSelection()
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func nightFlixSearchBarGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(.black.opacity(0.12)).interactive(),
                in: .rect(cornerRadius: 14)
            )
        } else {
            self.background(NightFlixStyle.fieldColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct MediaSearchResultsView: View {
    let title: String
    let viewModel: SearchViewModel
    let playErrorMessage: String?
    var isEntranceVisible = true
    var baseDelay = 0.0
    var animationsEnabled = true
    let onSelectResult: (MediaSearchResult) -> Void
    @State private var lastResultHapticSignature = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: title)
                .nightflixEntrance(isVisible: isEntranceVisible, delay: baseDelay, yOffset: 12, scaleAmount: 0.98, animationsEnabled: animationsEnabled)

            if let playErrorMessage {
                messageRow(playErrorMessage, systemImage: "exclamationmark.circle.fill")
            }

            if let errorMessage = viewModel.errorMessage {
                messageRow(errorMessage, systemImage: "info.circle.fill")
            } else if viewModel.didCompleteSearch && !viewModel.isLoading && viewModel.results.isEmpty {
                messageRow("No movies or TV series found.", systemImage: "tray.fill")
            }

            if viewModel.isLoading && !viewModel.hasResults && viewModel.hasActiveQuery {
                VStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { index in
                        SearchResultSkeletonView()
                            .nightflixEntrance(isVisible: isEntranceVisible, delay: cardDelay(index), yOffset: 14, animationsEnabled: animationsEnabled)
                    }
                }
            } else if viewModel.hasResults {
                VStack(spacing: 12) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.resultIdentifier) { index, result in
                        MediaResultCard(
                            result: result,
                            onSelectResult: onSelectResult
                        )
                        .nightflixEntrance(isVisible: isEntranceVisible, delay: cardDelay(index), yOffset: 14, animationsEnabled: animationsEnabled)
                    }
                }
            }
        }
        .onChange(of: resultHapticSignature) { _, newValue in
            guard !newValue.isEmpty, newValue != lastResultHapticSignature else { return }
            lastResultHapticSignature = newValue
            HapticManager.shared.searchResultsLoaded()
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if newValue != nil {
                HapticManager.shared.error()
            }
        }
    }

    private var resultHapticSignature: String {
        guard viewModel.didCompleteSearch, !viewModel.isLoading, viewModel.hasResults else { return "" }
        return viewModel.results.map(\.resultIdentifier).joined(separator: "|")
    }

    private func cardDelay(_ index: Int) -> Double {
        baseDelay + 0.06 + min(Double(index) * 0.055, 0.44)
    }

    private func messageRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NightFlixStyle.subtleFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct MediaResultCard: View {
    let result: MediaSearchResult
    let onSelectResult: (MediaSearchResult) -> Void

    var body: some View {
        Button {
            onSelectResult(result)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                NightFlixPosterImage(url: result.posterURL, width: 86, height: 128)

                VStack(alignment: .leading, spacing: 8) {
                    titleLine

                    if !result.overview.isEmpty {
                        Text(result.overview)
                            .font(.subheadline)
                            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.68))
                            .lineLimit(result.isMovie ? 4 : 3)
                    }

                    actionLabel
                        .padding(.top, 4)
                }
            }
            .contentShape(Rectangle())
            .nightFlixResultCardStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var titleLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.displayTitle)
                .font(.headline)
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .lineLimit(2)

            HStack(spacing: 8) {
                if let year = result.displayYear, !year.isEmpty {
                    Text(year)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.52))
                }

                Text(result.type.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.78))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(NightFlixStyle.fillColor(darkOpacity: 0.08), in: Capsule())
            }
        }
    }

    private var actionLabel: some View {
        Label("Play", systemImage: "play.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var accessibilityLabel: String {
        "Play \(result.displayTitle)"
    }
}

private extension MediaSearchResult {
    var resultIdentifier: String {
        "\(mediaType)-\(id)"
    }
}

#Preview {
    SearchView(
        historyManager: WatchHistoryManager(),
        continueWatchingManager: ContinueWatchingManager()
    )
}
