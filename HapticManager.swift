import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private enum HapticKey: String {
        case selection
        case lightImpact
        case mediumImpact
        case heavyImpact
        case softImpact
        case rigidImpact
        case success
        case warning
        case error
        case searchResultsLoaded
        case scrollTick
    }

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var lastFireDates: [String: Date] = [:]

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private init() { }

    func prepareSelection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
    }

    func prepareImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).prepare()
    }

    func selection() {
        selection(key: .selection)
    }

    func lightImpact() {
        impact(style: .light, key: .lightImpact)
    }

    func mediumImpact() {
        impact(style: .medium, key: .mediumImpact)
    }

    func heavyImpact() {
        impact(style: .heavy, key: .heavyImpact)
    }

    func softImpact() {
        impact(style: .soft, key: .softImpact)
    }

    func rigidImpact() {
        impact(style: .rigid, key: .rigidImpact)
    }

    func success() {
        notification(type: .success, key: .success)
    }

    func warning() {
        notification(type: .warning, key: .warning)
    }

    func error() {
        notification(type: .error, key: .error)
    }

    func searchResultsLoaded() {
        impact(style: .soft, key: .searchResultsLoaded, minimumInterval: 1.0, intensity: 0.45)
    }

    func scrollTick() {
        selection(key: .scrollTick, minimumInterval: 0.1)
    }

    private func selection(key: HapticKey, minimumInterval: TimeInterval = 0.08) {
        guard canFire(key.rawValue, minimumInterval: minimumInterval) else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    private func impact(
        style: UIImpactFeedbackGenerator.FeedbackStyle,
        key: HapticKey,
        minimumInterval: TimeInterval = 0.08,
        intensity: CGFloat? = nil
    ) {
        guard canFire(key.rawValue, minimumInterval: minimumInterval) else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
        generator.prepare()
    }

    private func notification(
        type: UINotificationFeedbackGenerator.FeedbackType,
        key: HapticKey,
        minimumInterval: TimeInterval = 0.08
    ) {
        guard canFire(key.rawValue, minimumInterval: minimumInterval) else { return }
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    private func canFire(_ key: String, minimumInterval: TimeInterval) -> Bool {
        guard isEnabled else { return false }

        let now = Date()
        if let lastFireDate = lastFireDates[key], now.timeIntervalSince(lastFireDate) < minimumInterval {
            return false
        }

        lastFireDates[key] = now
        return true
    }
}
