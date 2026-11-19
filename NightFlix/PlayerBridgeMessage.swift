import Foundation

/// A message forwarded from the embedded player page by `WebView`'s JavaScript bridge.
///
/// VidFast (the built-in provider) posts `window.postMessage` envelopes of the form
/// `{ type: "PLAYER_EVENT", data: { event, currentTime, duration, tmdbId, mediaType,
/// season, episode, … } }`, plus `{ event: "status", data: 404 }` when none of its
/// servers can play the title. The bridge also reports the user touching the page so
/// the native chrome can reappear alongside the player's own controls.
///
/// Older Videasy-style flat payloads (`{ id, type, timestamp, duration, progress }`)
/// are still understood, so a custom provider with that format keeps working.
enum PlayerBridgeMessage: Equatable {
    case progress(PlayerProgressEvent)
    /// The provider couldn't find a playable source for this title.
    case sourceUnavailable
    /// The user touched the player page.
    case userInteraction

    init?(payload: Any) {
        guard let root = Self.dictionary(from: payload) else { return nil }

        switch root["type"] as? String {
        case "NIGHTFLIX_INTERACTION":
            self = .userInteraction
            return
        case "MEDIA_DATA":
            // VidFast's periodic dump of its own local watch history — the
            // per-tick PLAYER_EVENTs already carry everything we need.
            return nil
        default:
            break
        }

        if (root["event"] as? String) == "status" {
            guard let code = PlayerPayload.int(root["data"]), code >= 400 else { return nil }
            self = .sourceUnavailable
            return
        }

        guard let event = PlayerProgressEvent(root: root) else { return nil }
        self = .progress(event)
    }

    private static func dictionary(from payload: Any) -> [String: Any]? {
        if let dictionary = payload as? [String: Any] {
            return dictionary
        }

        if let string = payload as? String,
           let data = string.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parsed
        }

        return nil
    }
}

/// A watch-progress update from the embedded player.
struct PlayerProgressEvent: Equatable {
    enum Kind: String {
        case play
        case pause
        case seeked
        case ended
        case timeUpdate = "timeupdate"
        case playerStatus = "playerstatus"
        /// A legacy flat progress payload with no discrete event name.
        case progress
    }

    let kind: Kind
    /// Current playback position in seconds.
    let currentTime: Double
    /// Total duration in seconds (0 when unknown).
    let duration: Double
    /// Watch progress as a percentage (0…100).
    let progress: Double
    /// TMDB id of the playing title, as a string.
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

    init(
        kind: Kind,
        currentTime: Double,
        duration: Double,
        progress: Double,
        id: String,
        mediaType: String,
        season: Int?,
        episode: Int?
    ) {
        self.kind = kind
        self.currentTime = currentTime
        self.duration = duration
        self.progress = progress
        self.id = id
        self.mediaType = mediaType
        self.season = season
        self.episode = episode
    }

    init?(root: [String: Any]) {
        // VidFast: { type: "PLAYER_EVENT", data: { event, currentTime, duration, … } }
        if (root["type"] as? String) == "PLAYER_EVENT" {
            guard let data = root["data"] as? [String: Any] else { return nil }

            let eventName = (data["event"] as? String)?.lowercased() ?? ""
            let currentTime = PlayerPayload.double(data["currentTime"]) ?? 0
            let duration = PlayerPayload.double(data["duration"]) ?? 0

            self.init(
                kind: Kind(rawValue: eventName) ?? .timeUpdate,
                currentTime: currentTime,
                duration: duration,
                progress: duration > 0 ? (currentTime / duration) * 100 : 0,
                id: PlayerPayload.string(data["tmdbId"])
                    ?? PlayerPayload.string(data["mtmdbId"])
                    ?? PlayerPayload.string(data["id"])
                    ?? "",
                mediaType: (data["mediaType"] as? String) ?? "",
                season: PlayerPayload.int(data["season"]),
                episode: PlayerPayload.int(data["episode"])
            )
            return
        }

        // Legacy flat payload (optionally wrapped in `data`).
        let data = (root["data"] as? [String: Any]) ?? root
        let timestamp = PlayerPayload.double(data["timestamp"]) ?? PlayerPayload.double(data["currentTime"])
        let reportedProgress = PlayerPayload.double(data["progress"])
        guard timestamp != nil || reportedProgress != nil else { return nil }

        self.init(
            kind: .progress,
            currentTime: timestamp ?? 0,
            duration: PlayerPayload.double(data["duration"]) ?? 0,
            progress: reportedProgress ?? 0,
            id: PlayerPayload.string(data["id"]) ?? PlayerPayload.string(data["tmdbId"]) ?? "",
            mediaType: (data["type"] as? String) ?? (data["mediaType"] as? String) ?? "",
            season: PlayerPayload.int(data["season"]),
            episode: PlayerPayload.int(data["episode"])
        )
    }
}

/// Tolerant readers for the loosely typed values JavaScript hands to native code.
private enum PlayerPayload {
    static func double(_ value: Any?) -> Double? {
        let result: Double?
        switch value {
        case let number as Double: result = number
        case let number as Int: result = Double(number)
        case let string as String: result = Double(string)
        default: result = nil
        }

        guard let result, result.isFinite else { return nil }
        return result
    }

    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as Double:
            guard number.isFinite else { return nil }
            return Int(number)
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            return string.isEmpty ? nil : string
        case let number as Int:
            return String(number)
        case let number as Double:
            guard number.isFinite else { return nil }
            return String(Int(number))
        default:
            return nil
        }
    }
}
