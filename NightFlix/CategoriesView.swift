import SwiftUI

struct CategoriesView: View {
    let historyManager: WatchHistoryManager
    let continueWatchingManager: ContinueWatchingManager
    @ObservedObject var myListManager: MyListManager

    @EnvironmentObject private var settings: AppSettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = CategoriesViewModel()
    @State private var selectedContentType: CategoryContentType = .movies
    @State private var selectedCategory: CategorySelection?
    @State private var entranceVisible = false

    private let genreColumns = [
        GridItem(.adaptive(minimum: 124), spacing: 10)
    ]

    var body: some View {
        ZStack {
            NightFlixStyle.backgroundColor.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    contentTypePicker
                    genreSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedCategory) { selection in
            CategoryDetailView(
                selection: selection,
                historyManager: historyManager,
                continueWatchingManager: continueWatchingManager,
                myListManager: myListManager
            )
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onAppear {
            startEntrance()
        }
        .onChange(of: selectedContentType) { _, _ in
            HapticManager.shared.selection()
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Categories")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(NightFlixStyle.primaryTextColor)
                .accessibilityAddTraits(.isHeader)

            Text("Browse by genre")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NightFlixStyle.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.06, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
    }

    private var contentTypePicker: some View {
        Picker("Content Type", selection: $selectedContentType) {
            ForEach(CategoryContentType.allCases) { contentType in
                Text(contentType.rawValue).tag(contentType)
            }
        }
        .pickerStyle(.segmented)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.12, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
    }

    private var genreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: selectedContentType.sectionTitle)

            if viewModel.isLoading(selectedContentType) && viewModel.genres(for: selectedContentType).isEmpty {
                GenreChipSkeletonGrid()
            } else if let errorMessage = viewModel.errorMessage(for: selectedContentType) {
                VStack(alignment: .leading, spacing: 10) {
                    messageRow(errorMessage, systemImage: "exclamationmark.circle.fill")
                    retryButton
                }
            } else if viewModel.genres(for: selectedContentType).isEmpty {
                messageRow("No genres are available right now.", systemImage: "tray.fill")
            } else {
                LazyVGrid(columns: genreColumns, alignment: .leading, spacing: 10) {
                    ForEach(Array(viewModel.genres(for: selectedContentType).enumerated()), id: \.element.id) { index, genre in
                        genreCard(genre)
                            .nightflixEntrance(isVisible: entranceVisible, delay: cardDelay(index), yOffset: 12, animationsEnabled: pageAnimationsEnabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .nightflixEntrance(isVisible: entranceVisible, delay: 0.18, yOffset: 12, scaleAmount: 0.98, animationsEnabled: pageAnimationsEnabled)
    }

    private func genreCard(_ genre: Genre) -> some View {
        Button {
            HapticManager.shared.mediumImpact()
            selectedCategory = CategorySelection(contentType: selectedContentType, genre: genre)
        } label: {
            HStack(spacing: 8) {
                Text(genre.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(NightFlixStyle.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.black))
                    .foregroundStyle(NightFlixStyle.accentColor)
            }
            .padding(.horizontal, 13)
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .background(NightFlixStyle.cardColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NightFlixStyle.borderColor(darkOpacity: 0.08), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(genre.name)")
    }

    private var retryButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            Task {
                await viewModel.reload()
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
        0.22 + min(Double(index) * 0.035, 0.3)
    }
}

#Preview {
    NavigationStack {
        CategoriesView(
            historyManager: WatchHistoryManager(),
            continueWatchingManager: ContinueWatchingManager(),
            myListManager: MyListManager()
        )
        .environmentObject(AppSettingsManager())
    }
}
