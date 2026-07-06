# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Coding conventions

- **Prefer native, first-party components wherever possible.** Reach for SwiftUI, SwiftData, MapKit, WidgetKit, and other Apple frameworks before writing custom implementations or adding third-party dependencies. The project ships with zero external package dependencies — keep it that way unless there's a compelling reason.
- **Write idiomatic Swift.** Match the existing style: value types and enums for modeling, computed properties over stored duplication, `@ViewBuilder`/small view structs, `MARK:` section comments, and comments that explain *why* rather than *what*.

## Build & run

This is a plain Xcode project (`Trip.xcodeproj`) — no workspace, no SPM/CocoaPods/Carthage. Two shared schemes: **Trip** (the app) and **TripWidgetExtension**.

```sh
# Build the app for a simulator
xcodebuild -project Trip.xcodeproj -scheme Trip \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

- Deployment target is **iOS 27.0**; Swift 5.
- There is **no test target** — do not assume a test suite exists.
- Both targets require the **`group.carlos-m.trips`** App Group entitlement (bundle id `com.carlos-m.trips`); this is how the app hands data to the widget.

### SwiftData has no migration plan

The app uses `.modelContainer(for: [TripDay.self, TripSegment.self])` with automatic lightweight migration only. **Adding or changing a mandatory `@Model` property breaks existing on-disk stores** (in-place migration fails and the store loads empty). When iterating on the model, delete the app from the simulator (or its `default.store`) to force a clean re-seed.

## Architecture

An **offline-first** iOS trip companion. Everything ships in the bundle; there is no network layer.

### Data flow: JSON → SwiftData → (snapshot) → Widget

1. **Bundled `trip.json`** (`Trip/Resources/`) is the authored itinerary. Its nested schema is `trip → days[] → segments[]`, where a segment may carry `files` (bundled PDF attachments), `commute` (mode + summary), and `pin` (lat/lng/address). The `Codable` DTOs that define this schema live at the bottom of `Seeding.swift`.
2. **`Seeding.seedIfNeeded`** decodes `trip.json` into SwiftData models on first launch. After that, **`TripDay`/`TripSegment` (in `Models.swift`) are the single source of truth** — completion is a plain stored `Bool`, mutated directly. Bundled JSON decode failures are programmer errors and `fatalError`; user-supplied JSON is validated and fails gracefully.
3. **Editing** (`EditTripView` + `Seeding.replaceAll`/`resetToBundled`/`exportJSON`) lets the user replace the whole trip from clipboard JSON, reset to bundled, or copy the current trip back out as JSON.
4. **The widget cannot see the SwiftData store.** Instead the app writes a small `Codable` snapshot (`WidgetSnapshot.publish` → `widget-snapshot.json` in the App Group container) and the widget reads it (`WidgetTripData` in the `TripWidget/` target). `WidgetSnapshotEvent` (app) and `SnapshotEvent` (widget) are **intentionally duplicated structs that must stay in sync**. `publish` is called from `TripListView.task` and after every edit in `EditTripView`.

### UI: map background + itinerary sheet

`RootMapView` is the root and the owner of app-wide state:

- A full-screen **`Map`** carries the top toolbar (locate button, filter menu). The itinerary is a **persistent, non-dismissable sheet** with three detents: calendar-only (`WeekCalendarBar.barHeight`), `.medium`, `.large`.
- **Filter state lives here** (`hideCompleted`, `hideCommutes`, `hiddenKinds`, `selectedDay`) and is passed down to `TripListView`. The *same predicate* (`matchesFilter`) is applied to both the map pins and the list, so they always agree; changing a filter reframes the map camera.
- `selected: TripSegment?` is the single source of truth for both the **detail sheet** (a nested sheet over the list, closed with an X — `SegmentDetailView`) and **map focus** (the camera frames the selected pin).
- `TripListView` renders the selected day's segments with commute cards between events, pinch-to-collapse row detail (`DetailLevel`), swipe-to-complete, and the soft scroll-edge effect under the pinned `WeekCalendarBar`.

### Cross-cutting pieces

- **`SegmentKind`** (`Models.swift`) is the category enum; its view extensions (colors, SF Symbols, `spectrumOrder`, `swatchImage`) live in `Rows.swift`. Category color rails appear in the app rows, the map markers, and the widget (the widget re-declares the color mapping since it can't import the app's types).
- **Dates are stored as `"yyyy-MM-dd"` strings**; all parsing/formatting goes through the POSIX `DateFormatter`s in the `DateText` helper. The "current"/in-progress event is derived from the device clock (the last segment whose start time has passed).
- **`Animations.swift`** defines the shared spring easings (`.trip`, `.tripInteractive`) — use these for consistency.
- **`LocationProvider`** wraps CoreLocation for the user dot and recenter control.
