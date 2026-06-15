import Foundation

/// A watch-progress event emitted by the Vidking embed player via `window.postMessage`.
///
/// The player wraps each event as `{ "type": "PLAYER_EVENT", "data": { … } }`. This
/// type models the inner `data` payload and is tolerant of missing or differently typed
/// fields, since the bridge receives loosely-typed JSON from JavaScript.
struct VidkingPlayerEvent: Equatable {
    enum Kind: String {
        case timeupdate
        case play
        case pause
        case ended
        case seeked
        case unknown
    }

    let event: Kind
    /// Current playback position in seconds.
    let currentTime: Double
    /// Total duration in seconds (0 when unknown).
    let duration: Double
    /// Watch progress as a percentage (0…100) as reported by the player.
    let progress: Double
    /// TMDB content id, as a string.
    let id: String
    /// "movie" or "tv".
    let mediaType: String
    let season: Int?
    let episode: Int?

    /// Fraction watched in `0...1`, derived from `currentTime/duration` when possible,
    /// otherwise from the reported percentage.
    var fraction: Double {
        let value: Double
        if duration > 0 {
            value = currentTime / duration
        } else {
            value = progress / 100
        }
        return min(max(value, 0), 1)
    }

    /// Builds an event from the loosely-typed dictionary delivered by the JS bridge.
    /// Accepts either the full envelope (`{type, data}`) or a bare `data` dictionary.
    init?(payload: Any) {
        let root: [String: Any]
        if let dictionary = payload as? [String: Any] {
            root = dictionary
        } else if let string = payload as? String,
                  let data = string.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        } else {
            return nil
        }

        // Reject envelopes that are explicitly not player events.
        if let envelopeType = root["type"] as? String, envelopeType != "PLAYER_EVENT" {
            return nil
        }

        // Unwrap the `{ "type": "PLAYER_EVENT", "data": { … } }` envelope if present.
        let data = (root["data"] as? [String: Any]) ?? root

        guard let rawEvent = data["event"] as? String else { return nil }

        event = Kind(rawValue: rawEvent) ?? .unknown
        currentTime = Self.double(data["currentTime"]) ?? 0
        duration = Self.double(data["duration"]) ?? 0
        progress = Self.double(data["progress"]) ?? 0
        id = Self.string(data["id"]) ?? ""
        mediaType = (data["mediaType"] as? String) ?? ""
        season = Self.int(data["season"])
        episode = Self.int(data["episode"])
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as Double: return number
        case let number as Int: return Double(number)
        case let string as String: return Double(string)
        default: return nil
        }
    }

    private static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as Double: return Int(number)
        case let string as String: return Int(string)
        default: return nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as Int: return String(number)
        case let number as Double: return String(Int(number))
        default: return nil
        }
    }
}
