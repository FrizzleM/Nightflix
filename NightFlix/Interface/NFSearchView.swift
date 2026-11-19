import Observation
import SwiftUI

/// Full-screen search: "Top Searches" while idle, a poster grid of films and series
/// (including what matching actors are known for) while typing.
struct NFSearchView: View {
    var body: some View {
        NFSearchScreen()
            .nfRouterHost()
            .preferredColorScheme(.dark)
    }
}

@Observable
final class NFSearchModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var results: [MediaItem] = []
    private(set) var isSearching = false
    private(set) var didFail = false
    private(set) var topSearches: [MediaItem] = []

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadTopSearches() async {
        guard topSearches.isEmpty else { return }
        let items = (try? await NFCatalogService.list(path: "/3/trending/all/day", fallbackType: nil)) ?? []
        topSearches = Array(items.filter { $0.isBrowsable && $0.backdropPath != nil }.prefix(18))
    }

    func retry() {
        scheduleSearch(debounce: false)
    }

    private func scheduleSearch(debounce: Bool = true) {
        searchTask?.cancel()

        let text = trimmedQuery
        guard !text.isEmpty else {
            results = []
            isSearching = false
            didFail = false
            return
        }

        isSearching = true
        searchTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(280))
            }
            guard !Task.isCancelled else { return }

            do {
                let found = try await NFCatalogService.search(text)
                guard !Task.isCancelled else { return }
                results = found.filter(\.isListable)
                didFail = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                didFail = true
            }

            isSearching = false
        }
    }
}

private struct NFSearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NFAppModel.self) private var app
    @Environment(NFRouter.self) private var router

    @State private var model = NFSearchModel()
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                searchBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if model.trimmedQuery.isEmpty {
                            topSearches
                        } else {
                            results(width: proxy.size.width)
                        }
                    }
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
            }
        }
        .background(NF.canvas.ignoresSafeArea())
        .task {
            await model.loadTopSearches()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isFieldFocused = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Button {
                HapticManager.shared.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(NF.textTertiary)

                TextField(
                    "",
                    text: $model.query,
                    prompt: Text("Search films, series, actors").foregroundStyle(NF.textTertiary)
                )
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isFieldFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                        isFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(NF.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(NF.surfaceRaised, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.leading, 6)
        .padding(.trailing, NF.gutter)
        .padding(.vertical, 8)
    }

    // MARK: Idle

    @ViewBuilder
    private var topSearches: some View {
        Text("Top Searches")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, NF.gutter)
            .padding(.top, 10)
            .padding(.bottom, 12)

        if model.topSearches.isEmpty {
            ForEach(0..<6, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonView(cornerRadius: 4)
                        .frame(width: 140, height: 78)
                    TextLineSkeletonView(width: 150, height: 12)
                    Spacer()
                }
                .padding(.horizontal, NF.gutter)
                .padding(.bottom, 6)
            }
        } else {
            LazyVStack(spacing: 6) {
                ForEach(model.topSearches, id: \.nfKey) { item in
                    topSearchRow(item)
                }
            }
        }
    }

    private func topSearchRow(_ item: MediaItem) -> some View {
        HStack(spacing: 12) {
            Button {
                isFieldFocused = false
                router.preview(item)
            } label: {
                HStack(spacing: 12) {
                    NFImage(url: NF.imageURL(item.backdropPath, .still))
                        .frame(width: 140, height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayTitle)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(NFMeta.line(for: item))
                            .font(.system(size: 12))
                            .foregroundStyle(NF.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NFPressableStyle(scale: 0.99))

            Button {
                app.play(item, router: router)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .overlay { Circle().strokeBorder(Color.white, lineWidth: 1.5) }
                    .contentShape(Circle())
            }
            .buttonStyle(NFPressableStyle(scale: 0.9))
            .accessibilityLabel("Play \(item.displayTitle)")
        }
        .padding(.horizontal, NF.gutter)
    }

    // MARK: Results

    @ViewBuilder
    private func results(width: CGFloat) -> some View {
        let spacing: CGFloat = 8
        let columnWidth = ((width - NF.gutter * 2 - spacing * 2) / 3).rounded(.down)

        if model.results.isEmpty {
            if model.isSearching {
                LazyVGrid(columns: columns(width: columnWidth, spacing: spacing), spacing: spacing) {
                    ForEach(0..<9, id: \.self) { _ in
                        SkeletonView(cornerRadius: NF.posterCorner)
                            .frame(width: columnWidth, height: columnWidth * 1.5)
                    }
                }
                .padding(.horizontal, NF.gutter)
                .padding(.top, 16)
            } else if model.didFail {
                emptyState(
                    title: "Search isn't working right now",
                    message: "Check your connection and try again.",
                    showsRetry: true
                )
            } else {
                emptyState(
                    title: "No matches for “\(model.trimmedQuery)”",
                    message: "Try another title, actor or genre.",
                    showsRetry: false
                )
            }
        } else {
            Text("Films & Series")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, NF.gutter)
                .padding(.top, 10)
                .padding(.bottom, 12)

            LazyVGrid(columns: columns(width: columnWidth, spacing: spacing), alignment: .leading, spacing: spacing) {
                ForEach(model.results, id: \.nfKey) { item in
                    NFPosterButton(item: item, width: columnWidth) { selected in
                        isFieldFocused = false
                        router.preview(selected)
                    }
                }
            }
            .padding(.horizontal, NF.gutter)
        }
    }

    private func columns(width: CGFloat, spacing: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.fixed(width), spacing: spacing), count: 3)
    }

    private func emptyState(title: String, message: String, showsRetry: Bool) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(NF.textTertiary)
                .multilineTextAlignment(.center)

            if showsRetry {
                Button("Try Again") {
                    model.retry()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 90)
    }
}
