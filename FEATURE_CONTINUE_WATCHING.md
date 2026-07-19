# Feature Prompt: Real "Continue Watching" with Resume (Videasy progress tracking)

## One-line pitch
Make the existing "Continue Watching" rail real: capture live watch progress from
the Videasy player, persist it per title/episode, show a true progress bar, and
**resume playback from where the user left off**.

## Why this feature
The "Continue Watching" row already exists, but it's cosmetic: every tile shows a
hardcoded `0.35` progress bar, and tapping a tile restarts the video from `0:00`.
The Videasy player (the app's streaming provider, `player.videasy.net`) emits
watch-progress events to the parent window and accepts a `?progress=<seconds>`
start-time parameter — so the data and the resume hook already exist. We just aren't
using them.

## Videasy integration facts (from the provider's docs)
- Embed routes (already built by `StreamingProviderURLBuilder`):
  - Movie: `/movie/{tmdbId}`
  - TV: `/tv/{tmdbId}/{season}/{episode}`
- Resume parameter: `?progress=<seconds>` — starts playback at that position.
- The player posts `window.postMessage` updates to the parent window as a JSON string
  with a flat payload (no envelope):
  ```json
  { "id": "299534", "type": "movie", "progress": 1.6,
    "timestamp": 120.5, "duration": 7200, "season": 1, "episode": 8 }
  ```
  - The player streams these progress updates periodically; there are no discrete
    play/pause/ended event kinds.
  - `timestamp` = seconds position, `duration` = total seconds, `progress` = percent.

## User-facing behavior
1. While a title plays, the app records its position in the background.
2. The Continue Watching tile shows the **real** fraction watched (bar hidden until
   there's measurable progress).
3. Tapping a Continue Watching tile **resumes** at the saved second (`?progress=`).
4. Re-playing the same movie/episode from its detail screen also resumes, so progress
   is never silently reset to zero.
5. For series, the entry tracks the **current** episode (the in-player next-episode /
   episode-selector controls move it forward), and the subtitle reflects S/E.
6. A finished movie leaves the rail (once effectively fully watched); a finished episode
   lets the series advance to the next episode.

## Scope / requirements
- **Capture (`WebView.swift`)**: add a `WKScriptMessageHandler` + an injected
  `WKUserScript` that listens for the player's `message` events and forwards the
  progress payloads to native. Expose an `onPlayerEvent` callback. Use a weak
  message-handler proxy to avoid a retain cycle. Preserve the existing loading/error
  states.
- **Event model (new `NightFlix/VideasyPlayerEvent.swift`)**: a typed struct parsed
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
  events (ignore mismatched `id`), throttle progress persistence (~5s), and finish a
  movie once it's effectively fully watched (~95%).
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
