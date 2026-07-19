import Foundation

/// A watch-progress update emitted by the Videasy embed player via `window.postMessage`.
///
/// Videasy delivers each update as a JSON string on `event.data` with a flat payload —
/// there is no `{ type, data }` envelope and no discrete event kinds; the player simply
/// streams periodic progress. This type models that payload and is tolerant of missing
/// or differently typed fields, since the bridge receives loosely-typed JSON from
/// JavaScript.
///
/// Documented fields: `id`, `type` (movie/tv/anime), `progress` (percent), `timestamp`
/// (playback position in seconds), `duration` (seconds), `season`, `episode`.
struct VideasyPlayerEvent: Equatable {
    /// Current playback position in seconds (Videasy's `timestamp`).
    let currentTime: Double
    /// Total duration in seconds (0 when unknown).
    let duration: Double
    /// Watch progress as a percentage (0…100) as reported by the player.
    let progress: Double
    /// Content id, as a string.
    let id: String
    /// "movie", "tv", or "anime".
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

    /// Builds an event from the loosely-typed value delivered by the JS bridge, which is
    /// either a decoded dictionary or a JSON string. Tolerates an optional `data` wrapper
    /// and, for resilience, Videasy's `timestamp`/`type` keys as well as the legacy
    /// `currentTime`/`mediaType` names.
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

        // Unwrap an optional `{ "data": { … } }` wrapper if one is present.
        let data = (root["data"] as? [String: Any]) ?? root

        // A genuine progress update carries a playback position and/or a percentage.
        let timestamp = Self.double(data["timestamp"]) ?? Self.double(data["currentTime"])
        let reportedProgress = Self.double(data["progress"])
        guard timestamp != nil || reportedProgress != nil else { return nil }

        currentTime = timestamp ?? 0
        duration = Self.double(data["duration"]) ?? 0
        progress = reportedProgress ?? 0
        id = Self.string(data["id"]) ?? ""
        mediaType = (data["type"] as? String) ?? (data["mediaType"] as? String) ?? ""
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
