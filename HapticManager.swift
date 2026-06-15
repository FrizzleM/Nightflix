import UIKit
import CoreHaptics

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
        case pop
        case pressDown
        case release
        case doubleTap
        case impactStrong
        case bloom
        case rampUp
        case toggleOn
        case toggleOff
        case tabChange
    }

    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var lastFireDates: [String: Date] = [:]

    // Core Haptics gives us crisp, layered, intensity-shaped feedback far beyond
    // the three canned UIKit generators. We keep the generators as a fallback for
    // devices without Core Haptics (and the simulator).
    private let supportsCoreHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?
    private var engineNeedsStart = true

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    private init() {
        prepareEngine()
    }

    // MARK: - Preparation

    func prepareSelection() {
        guard isEnabled else { return }
        selectionGenerator.prepare()
        _ = startEngineIfNeeded()
    }

    func prepareImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).prepare()
        _ = startEngineIfNeeded()
    }

    // MARK: - Core feedback (UIKit-parity, but punchier via Core Haptics)

    func selection() {
        perform(.selection,
                events: [transient(intensity: 0.5, sharpness: 0.8)],
                fallback: { self.fireSelection() })
    }

    func lightImpact() {
        perform(.lightImpact,
                events: [transient(intensity: 0.55, sharpness: 0.5)],
                fallback: { self.fireImpact(.light) })
    }

    func mediumImpact() {
        perform(.mediumImpact,
                events: [transient(intensity: 0.8, sharpness: 0.55)],
                fallback: { self.fireImpact(.medium) })
    }

    func heavyImpact() {
        perform(.heavyImpact,
                events: [transient(intensity: 1.0, sharpness: 0.6)],
                fallback: { self.fireImpact(.heavy) })
    }

    func softImpact() {
        perform(.softImpact,
                events: [transient(intensity: 0.55, sharpness: 0.18)],
                fallback: { self.fireImpact(.soft) })
    }

    func rigidImpact() {
        perform(.rigidImpact,
                events: [transient(intensity: 0.85, sharpness: 0.95)],
                fallback: { self.fireImpact(.rigid) })
    }

    func success() {
        perform(.success, events: [
            transient(0, intensity: 0.6, sharpness: 0.5),
            transient(0.12, intensity: 1.0, sharpness: 0.7)
        ], fallback: { self.fireNotification(.success) })
    }

    func warning() {
        perform(.warning, events: [
            transient(0, intensity: 0.85, sharpness: 0.4),
            transient(0.16, intensity: 0.6, sharpness: 0.3)
        ], fallback: { self.fireNotification(.warning) })
    }

    func error() {
        perform(.error, events: [
            transient(0, intensity: 1.0, sharpness: 0.5),
            transient(0.1, intensity: 0.7, sharpness: 0.4),
            transient(0.2, intensity: 1.0, sharpness: 0.55)
        ], fallback: { self.fireNotification(.error) })
    }

    func searchResultsLoaded() {
        perform(.searchResultsLoaded, minimumInterval: 1.0,
                events: [transient(intensity: 0.45, sharpness: 0.25)],
                fallback: { self.fireImpact(.soft, intensity: 0.45) })
    }

    func scrollTick() {
        perform(.scrollTick, minimumInterval: 0.1,
                events: [transient(intensity: 0.32, sharpness: 0.65)],
                fallback: { self.fireSelection() })
    }

    // MARK: - Expressive feedback

    /// Punchy single tick — a confident "open" for tapping artwork or content.
    func pop() {
        perform(.pop, minimumInterval: 0.04,
                events: [transient(intensity: 1.0, sharpness: 0.7)],
                fallback: { self.fireImpact(.medium) })
    }

    /// Crisp light tick the instant a control is pressed down (before release).
    func pressDown() {
        perform(.pressDown, minimumInterval: 0.02,
                events: [transient(intensity: 0.45, sharpness: 0.85)],
                fallback: { self.fireImpact(.light, intensity: 0.5) })
    }

    /// Gentle tick on release.
    func release() {
        perform(.release, minimumInterval: 0.02,
                events: [transient(intensity: 0.3, sharpness: 0.3)],
                fallback: { self.fireImpact(.soft, intensity: 0.4) })
    }

    /// Two quick equal taps.
    func doubleTap() {
        perform(.doubleTap, minimumInterval: 0.04, events: [
            transient(0, intensity: 0.75, sharpness: 0.8),
            transient(0.08, intensity: 0.75, sharpness: 0.8)
        ], fallback: { self.fireImpact(.rigid) })
    }

    /// Big, intense thud with a short body — emphatic confirmations like Play.
    func impactStrong() {
        perform(.impactStrong, minimumInterval: 0.05, events: [
            transient(0, intensity: 1.0, sharpness: 0.6),
            continuous(0, duration: 0.13, intensity: 0.75, sharpness: 0.3)
        ], fallback: { self.fireImpact(.heavy) })
    }

    /// Satisfying swell — a tap that blooms into a short rising buzz, for
    /// positive moments like adding to My List.
    func bloom() {
        let body = continuous(0, duration: 0.32, intensity: 0.7, sharpness: 0.35)
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.2),
            .init(relativeTime: 0.16, value: 1.0),
            .init(relativeTime: 0.32, value: 0.0)
        ], relativeTime: 0)
        perform(.bloom, minimumInterval: 0.06,
                events: [transient(0, intensity: 0.9, sharpness: 0.7), body],
                curves: [curve],
                fallback: { self.fireNotification(.success) })
    }

    /// Rising envelope for building / long-press style interactions.
    func rampUp(duration: TimeInterval = 0.4) {
        let event = continuous(0, duration: duration, intensity: 0.85, sharpness: 0.4)
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 0.08),
            .init(relativeTime: duration, value: 1.0)
        ], relativeTime: 0)
        perform(.rampUp, minimumInterval: 0.1, events: [event], curves: [curve],
                fallback: { self.fireImpact(.heavy) })
    }

    /// Bright "switched on" — a single sharp tick.
    func toggleOn() {
        perform(.toggleOn, minimumInterval: 0.04,
                events: [transient(intensity: 1.0, sharpness: 0.85)],
                fallback: { self.fireImpact(.rigid) })
    }

    /// Muted "switched off" — a single soft tick.
    func toggleOff() {
        perform(.toggleOff, minimumInterval: 0.04,
                events: [transient(intensity: 0.6, sharpness: 0.35)],
                fallback: { self.fireImpact(.soft) })
    }

    /// Crisp single tick when switching tabs.
    func tabChange() {
        perform(.tabChange, minimumInterval: 0.05,
                events: [transient(intensity: 0.8, sharpness: 0.9)],
                fallback: { self.fireSelection() })
    }

    // MARK: - Dispatch

    private func perform(
        _ key: HapticKey,
        minimumInterval: TimeInterval = 0.08,
        events: @autoclosure () -> [CHHapticEvent],
        curves: @autoclosure () -> [CHHapticParameterCurve] = [],
        fallback: () -> Void
    ) {
        guard canFire(key.rawValue, minimumInterval: minimumInterval) else { return }

        if supportsCoreHaptics, play(events: events(), curves: curves()) {
            return
        }

        fallback()
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

    // MARK: - Core Haptics engine

    private func prepareEngine() {
        guard supportsCoreHaptics, engine == nil else { return }

        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                Task { @MainActor in self?.engineNeedsStart = true }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.engineNeedsStart = true }
            }
            self.engine = engine
        } catch {
            self.engine = nil
        }
    }

    private func startEngineIfNeeded() -> Bool {
        guard supportsCoreHaptics else { return false }
        if engine == nil { prepareEngine() }
        guard let engine else { return false }
        guard engineNeedsStart else { return true }

        do {
            try engine.start()
            engineNeedsStart = false
            return true
        } catch {
            return false
        }
    }

    private func play(events: [CHHapticEvent], curves: [CHHapticParameterCurve]) -> Bool {
        guard !events.isEmpty, startEngineIfNeeded(), let engine else { return false }

        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            engineNeedsStart = true
            return false
        }
    }

    private func transient(_ time: TimeInterval = 0, intensity: Float, sharpness: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time)
    }

    private func continuous(
        _ time: TimeInterval = 0,
        duration: TimeInterval,
        intensity: Float,
        sharpness: Float
    ) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: time, duration: duration)
    }

    // MARK: - UIKit fallback (no gating; the caller already passed canFire)

    private func fireSelection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    private func fireImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat? = nil) {
        let generator = UIImpactFeedbackGenerator(style: style)
        if let intensity {
            generator.impactOccurred(intensity: intensity)
        } else {
            generator.impactOccurred()
        }
        generator.prepare()
    }

    private func fireNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }
}
