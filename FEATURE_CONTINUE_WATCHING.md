# Feature Prompt: Real "Continue Watching" with Resume (Vidking progress tracking)

## One-line pitch
Make the existing "Continue Watching" rail real: capture live watch progress from
the Vidking player, persist it per title/episode, show a true progress bar, and
**resume playback from where the user left off**.

## Why this feature
The "Continue Watching" row already exists, but it's cosmetic: every tile shows a
hardcoded `0.35` progress bar, and tapping a tile restarts the video from `0:00`.
The Vidking player (the app's streaming provider, `vidking.net`) emits watch-progress
events to the parent window and accepts a `?progress=<seconds>` start-time parameter —
so the data and the resume hook already exist. We just aren't using them.

## Vidking integration facts (from the provider's docs)
- Embed routes (already built by `StreamingProviderURLBuilder`):
  - Movie: `/embed/movie/{tmdbId}`
  - TV: `/embed/tv/{tmdbId}/{season}/{episode}`
- Resume parameter: `?progress=<seconds>` — starts playback at that position.
- The player posts `window.postMessage` events to the parent window. Payload:
  ```json
  { "type": "PLAYER_EVENT",
    "data": { "event": "timeupdate|play|pause|ended|seeked",
              "currentTime": 120.5, "duration": 7200, "progress": 1.6,
              "id": "299534", "mediaType": "movie", "season": 1, "episode": 8,
              "timestamp": 1640995200000 } }
  ```
  - `timeupdate` streams continuously; `play`/`pause`/`seeked`/`ended` are discrete.
  - `currentTime` = seconds position, `duration` = total seconds, `progress` = percent.

## User-facing behavior
1. While a title plays, the app records its position in the background.
2. The Continue Watching tile shows the **real** fraction watched (bar hidden until
   there's measurable progress).
3. Tapping a Continue Watching tile **resumes** at the saved second (`?progress=`).
4. Re-playing the same movie/episode from its detail screen also resumes, so progress
   is never silently reset to zero.
5. For series, the entry tracks the **current** episode (the in-player next-episode /
   episode-selector controls move it forward), and the subtitle reflects S/E.
6. A finished movie leaves the rail (on `ended` or ~complete); a finished episode lets
   the series advance to the next episode.

## Scope / requirements
- **Capture (`WebView.swift`)**: add a `WKScriptMessageHandler` + an injected
  `WKUserScript` that listens for the player's `message` events and forwards
  `PLAYER_EVENT` payloads to native. Expose an `onPlayerEvent` callback. Use a weak
  message-handler proxy to avoid a retain cycle. Preserve the existing loading/error
  states.
- **Event model (new `NightFlix/VidkingPlayerEvent.swift`)**: a typed struct parsed
  from the JS payload (`[String: Any]` or JSON string), tolerant of missing fields.
- **Persistence (`ContinueWatchingItem.swift`)**: add optional `progressSeconds` and
  `durationSeconds`, plus a clamped `progressFraction`. Keep `Codable`
  backward-compatible (new keys optional → old stored data still decodes).
- **Store (`ContinueWatchingManager.swift`)**: `recordProgress(...)` (merge progress
  into the matching type+tmdbId entry, preserving title/poster, updating S/E + recency,
  insert if absent), `markFinished(type:tmdbId:)` (remove), and
  `resumeSeconds(type:tmdbId:season:episode:)` (the resume position for an exact
  movie/episode, only when meaningfully into the title and not near the end).
- **Resume URLs (`StreamingProviderURLBuilder`)**: add an optional
  `progressSeconds` parameter to `movieURL`/`tvURL` that appends `?progress=` when set.
- **Player wiring (`PlayerView.swift`)**: accept the `ContinueWatchingManager`, handle
  events (ignore mismatched `id`), throttle `timeupdate` persistence (~5s), persist
  immediately on pause/seek, and finish on `ended`.
- **Play paths**: every play action (Continue Watching tile, hero, movie detail,
  episode in both detail screens) resolves a resume position via `resumeSeconds` and
  passes it to the URL builder.
- **UI (`ContinueWatchingTile` + `FeedView`)**: drive the tile's bar from the item's
  real `progressFraction`; hide the bar when there's no progress yet.

## Constraints (match the codebase)
- SwiftUI/WebKit only, no new dependencies. Reuse existing styles, haptics, managers.
- No UserDefaults schema break: existing Continue Watching entries must keep loading.
- Don't regress the player's loading spinner or "Page failed to load" UI.

## Acceptance criteria
- Builds for the simulator with no new warnings.
- Playing a title then returning Home shows a Continue Watching tile with a real,
  non-default progress bar and correct S/E subtitle.
- Tapping that tile (or re-playing from detail) starts at the saved second.
- A movie that reaches the end leaves the rail; a series advances by episode.
- Old persisted Continue Watching items still load without error.
