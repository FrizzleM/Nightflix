# Feature Prompt: "Because You Watched" — Personalized Recommendation Rows

## One-line pitch
Turn NightFlix's identical-for-everyone Home feed into a personal one by adding
Netflix-style **"Because you watched …"** rows that recommend titles based on what
the user has actually played.

## Why this feature
Right now every user sees the same Home feed: Trending / Top 10 / Popular / Top
Rated. The app already records what the user plays (`WatchHistoryManager`) and TMDB
exposes a high-quality `/recommendations` endpoint for every movie and series — the
detail screen already uses it. Nothing on Home reacts to the user's taste. This
feature closes that gap and is the single most recognizable Netflix behavior the app
is missing.

## User-facing behavior
1. After a user plays something, the Home feed grows one or more **"Because you
   watched <Title>"** rows, each seeded from a recently watched title and filled with
   TMDB recommendations for it.
2. Rows sit right after **Continue Watching** and before **Top 10 This Week**, so the
   personal content is high on the page but doesn't displace the hero/continue rails.
3. Tapping any poster opens the existing `MediaDetailView`, exactly like every other
   poster row.
4. The rows update when watch history changes (watch something new → a fresh row
   appears the next time Home is shown) and refresh on pull-to-refresh.
5. New users with no watch history see no change — the section renders nothing and
   the existing generic rows carry the page. No empty states, spinners-to-nowhere, or
   layout jumps.

## Scope / requirements
- **Data layer (`TMDBService.swift`)**: add `movieRecommendations(movieId:)` and
  `tvRecommendations(seriesId:)` returning `[MediaRecommendationItem]`, hitting
  `/3/movie/{id}/recommendations` and `/3/tv/{id}/recommendations`. Reuse the existing
  cached request path; recommendations can use the default (long) cache TTL.
- **Model glue (`TMDBModels.swift`)**: add a `FeedItem(recommendation:fallbackType:)`
  initializer so recommendation results render in the existing poster rows. Resolve
  the media type from the item's `media_type` when present, else the seed's type.
- **View model (`FeedViewModel.swift`)**:
  - Add a `PersonalizedRow` value type (`id`, `seedTitle`, `items: [FeedItem]`) and
    `personalizedRows: [PersonalizedRow]` plus an `isLoadingPersonalizedRows` flag.
  - Add `loadPersonalizedRows(from history: [WatchItem], force: Bool = false)`:
    - Take the most-recent **distinct** watched titles (by type + tmdbId), cap at 4
      seeds; skip items whose tmdbId isn't an `Int`.
    - Fetch each seed's recommendations concurrently.
    - Filter out titles the user has already watched, drop the seed itself, and
      **de-duplicate globally** so the same poster never appears in two rows.
    - Keep only rows with a useful number of items (≥4); cap items per row (~16).
    - Short-circuit when the seed signature is unchanged unless `force` is set, so it
      doesn't refetch on every recomposition.
- **UI (`FeedView.swift`)**:
  - Render the rows as a new section between Continue Watching and Top 10, reusing the
    existing horizontally-scrolling poster-row chrome (`SectionHeaderView`,
    `PosterCard`, scroll haptics, `nightflixEntrance` staggered animation).
  - Header text: `Because you watched <Title>`.
  - Trigger `loadPersonalizedRows` after `loadIfNeeded()` and again on
    `historyManager.items` change; force-refresh inside the existing pull-to-refresh.
  - Only show when not in search mode. Show a single skeleton row while the first
    personalized fetch is in flight **and** the user actually has history.

## Constraints (match the codebase)
- Respect the existing animation system (`AppSettingsManager.animationMode`,
  `reduceMotion`, `nightflixEntrance`, `showContent`) and haptics
  (`HapticManager`).
- Keep `FeedViewModel` `@MainActor` and request-id/cancellation-safe like the existing
  section loads.
- No new third-party dependencies. SwiftUI only. Reuse existing styles
  (`NightFlixStyle`, `NightflixLayout`).
- Degrade gracefully: any failed recommendation fetch just yields no row for that
  seed; never surface an error banner for personalization.

## Acceptance criteria
- Project builds for the iOS simulator with no new warnings.
- With watch history present, Home shows one or more correctly-titled
  "Because you watched …" rows whose posters open the detail screen.
- With no history, Home is visually unchanged from today.
- Watching a new title and returning to Home surfaces a new/updated row.
- No duplicate posters across the personalized rows, and no title the user already
  watched appears in them.
