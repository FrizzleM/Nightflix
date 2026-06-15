import SwiftUI

struct MyListView: View {
    @ObservedObject var myListManager: MyListManager
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

            if myListManager.items.isEmpty {
                emptyState
                    .padding(24)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Watch Later")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(NightFlixStyle.primaryTextColor)
                            .accessibilityAddTraits(.isHeader)
                            .nightflixEntrance(isVisible: entranceVisible, delay: 0.06, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(Array(myListManager.items.enumerated()), id: \.element.id) { index, item in
                                MyListCardView(
                                    item: item,
                                    onSelect: {
                                        HapticManager.shared.mediumImpact()
                                        selectedDetailItem = item.mediaItem
                                    },
                                    onRemove: {
                                        HapticManager.shared.lightImpact()
                                        myListManager.remove(mediaType: item.mediaType, tmdbId: item.tmdbId)
                                    }
                                )
                                .nightflixEntrance(isVisible: entranceVisible, delay: cardDelay(index), yOffset: 14, animationsEnabled: pageAnimationsEnabled)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 130)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle("Watch Later")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDetailItem) { item in
            MediaDetailView(
                item: item,
                historyManager: historyManager,
                continueWatchingManager: continueWatchingManager,
                myListManager: myListManager
            )
        }
        .onAppear {
            myListManager.load()
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

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(NightFlixStyle.accentColor)

            Text("Watch Later is empty")
                .font(.title2.weight(.black))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .multilineTextAlignment(.center)

            Text("Save movies and series from their detail pages to watch later.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightFlixStyle.secondaryTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.08, yOffset: 14, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
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
        0.12 + min(Double(index) * 0.045, 0.34)
    }
}

#Preview {
    NavigationStack {
        MyListView(
            myListManager: MyListManager(),
            historyManager: WatchHistoryManager(),
            continueWatchingManager: ContinueWatchingManager()
        )
        .environmentObject(AppSettingsManager())
    }
}
