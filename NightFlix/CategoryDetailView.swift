import SwiftUI

struct CategoryDetailView: View {
    let selection: CategorySelection
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    @ObservedObject var myListManager: MyListManager

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = CategoryDetailViewModel()
    @State private var selectedDetailItem: MediaItem?
    @State private var entranceVisible = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    resultsContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(selection.genre.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDetailItem) { item in
            MediaDetailView(
                item: item,
                historyManager: historyManager,
                continueWatchingManager: continueWatchingManager,
                myListManager: myListManager
            )
        }
        .task {
            await viewModel.loadIfNeeded(selection: selection)
        }
        .onAppear {
            startEntrance()
        }
        .onChange(of: settings.animationMode) { _, _ in
            keepContentVisible()
        }
        .onChange(of: reduceMotion) { _, _ in
            keepContentVisible()
        }
        .tint(NightFlixStyle.accentColor)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selection.genre.name)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .accessibilityAddTraits(.isHeader)

            Text(selection.contentType.rawValue)
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(NightFlixStyle.accentColor, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.06, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
    }

    @ViewBuilder
    private var resultsContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            PosterGridSkeletonView()
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.12, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
        } else if let errorMessage = viewModel.errorMessage {
            VStack(alignment: .leading, spacing: 10) {
                messageRow(errorMessage, systemImage: "exclamationmark.circle.fill")
                retryButton
            }
            .nightflixEntrance(isVisible: entranceVisible, delay: 0.12, yOffset: 12, animationsEnabled: pageAnimationsEnabled)
        } else if viewModel.didLoad && viewModel.items.isEmpty {
            messageRow("No titles are available for this category right now.", systemImage: "tray.fill")
                .nightflixEntrance(isVisible: entranceVisible, delay: 0.12, yOffset: 12, animationsEnabled: pageAnimationsEnabled)
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element) { index, item in
                    CategoryMediaCardView(item: item) {
                        HapticManager.shared.mediumImpact()
                        selectedDetailItem = item
                    }
                    .nightflixEntrance(isVisible: entranceVisible, delay: cardDelay(index), yOffset: 14, animationsEnabled: pageAnimationsEnabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var retryButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            Task {
                await viewModel.reload(selection: selection)
            }
        } label: {
            Text("Retry")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .foregroundStyle(.white)
                .background(NightFlixStyle.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func messageRow(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(NightFlixStyle.textColor(darkOpacity: 0.75))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(NightFlixStyle.subtleFillColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pageAnimationsEnabled: Bool {
        settings.animationMode != .off && !reduceMotion
    }

    private func startEntrance() {
        guard !entranceVisible else { return }

        guard pageAnimationsEnabled else {
            keepContentVisible()
            return
        }

        withAnimation(.easeOut(duration: 0.35)) {
            entranceVisible = true
        }
    }

    private func keepContentVisible() {
        var transaction = Transaction()
        transaction.animation = nil

        withTransaction(transaction) {
            entranceVisible = true
        }
    }

    private func cardDelay(_ index: Int) -> Double {
        0.18 + min(Double(index) * 0.04, 0.36)
    }
}

private struct CategoryMediaCardView: View {
    let item: MediaItem
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            NightflixPoster(url: item.posterURL)
                .contentShape(Rectangle())
        }
        .buttonStyle(NightflixPressableStyle())
        .accessibilityLabel(item.displayTitle)
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(
            selection: CategorySelection(contentType: .movies, genre: Genre(id: 28, name: "Action")),
            historyManager: WatchHistoryManager(),
            continueWatchingManager: ContinueWatchingManager(),
            myListManager: MyListManager()
        )
        .environmentObject(AppSettingsManager())
    }
}
