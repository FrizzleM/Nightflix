import SwiftUI

struct ScrollHapticItem: Equatable {
    let index: Int
    let leadingDistance: CGFloat
}

struct ScrollHapticPreferenceKey: PreferenceKey {
    static var defaultValue: [ScrollHapticItem] = []

    static func reduce(value: inout [ScrollHapticItem], nextValue: () -> [ScrollHapticItem]) {
        value.append(contentsOf: nextValue())
    }
}

struct HorizontalScrollHapticModifier: ViewModifier {
    let coordinateSpaceName: String
    let isEnabled: Bool

    @State private var focusedIndex: Int?
    @State private var isReadyForHaptics = false

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: coordinateSpaceName)
            .onAppear {
                isReadyForHaptics = false
                focusedIndex = nil

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    isReadyForHaptics = true
                }
            }
            .onDisappear {
                isReadyForHaptics = false
                focusedIndex = nil
            }
            .onPreferenceChange(ScrollHapticPreferenceKey.self) { items in
                updateFocusedIndex(from: items)
            }
    }

    private func updateFocusedIndex(from items: [ScrollHapticItem]) {
        guard isEnabled, let closestItem = items.min(by: { $0.leadingDistance < $1.leadingDistance }) else {
            return
        }

        guard isReadyForHaptics else {
            focusedIndex = closestItem.index
            return
        }

        guard focusedIndex != closestItem.index else { return }
        focusedIndex = closestItem.index
        HapticManager.shared.scrollTick()
    }
}

extension View {
    func horizontalScrollHaptics(coordinateSpaceName: String, isEnabled: Bool = true) -> some View {
        modifier(HorizontalScrollHapticModifier(coordinateSpaceName: coordinateSpaceName, isEnabled: isEnabled))
    }

    func scrollHapticCard(index: Int, coordinateSpaceName: String, leadingAnchor: CGFloat = 20) -> some View {
        background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named(coordinateSpaceName))
                Color.clear.preference(
                    key: ScrollHapticPreferenceKey.self,
                    value: [
                        ScrollHapticItem(
                            index: index,
                            leadingDistance: abs(frame.minX - leadingAnchor)
                        )
                    ]
                )
            }
        }
    }
}
