# Photrail

Photrail automatically turns your photo library into a beautiful travel map. It reads the GPS metadata already embedded in your photos — no manual tagging, no accounts, no cloud.

---

## Features

- **World map** — Interactive map with a pin for every country you've visited
- **Travel statistics** — Countries visited, cities explored, percentage of the world covered, most photographed country
- **Continents overview** — See how many of the 6 inhabited continents you've visited, with a detail screen listing every visited country per continent
- **Monthly activity timeline** — Bar chart showing your photo activity over time
- **Country detail view** — Photo grid, city breakdown, and visit history per country
- **Shareable cards** — Export beautiful stat cards in four themes (Midnight, Dawn, Forest, Ocean) via the native share sheet
- **Live scanning** — The dashboard populates in real time as your library is processed; no waiting on a loading screen
- **Durable, resumable processing** — Every geocoding result is persisted to a local SwiftData (SQLite) store the moment it completes, so closing or killing the app never loses progress — it always resumes exactly where it left off
- **Background processing** — Scanning and geocoding continue while the app is in the background via `BGProcessingTask`

## Privacy

Everything runs entirely on-device.

- No backend, no accounts, no analytics
- Photos never leave your phone
- Only EXIF GPS metadata is read — actual image data is only loaded when displaying thumbnails
- All travel data is stored in a local on-device SwiftData database
- Photo library access can be revoked at any time in Settings

## Requirements

- iOS 18+
- Xcode 16+

## Architecture

Clean MVVM with Swift Concurrency throughout.

```
Photrail/
├── App/
│   └── RootView.swift                  State machine: onboarding → dashboard
├── Models/
│   ├── GeoPhoto.swift                  Single geotagged photo value type (Sendable DTO)
│   ├── StoredPhoto.swift               SwiftData @Model — one SQLite row per photo
│   ├── CountryStat.swift               Aggregated country + city statistics
│   ├── ContinentStat.swift             Continent enum + per-continent aggregation
│   └── TravelStats.swift               Full stats snapshot + mock data for previews
├── Services/
│   ├── PhotoScanService.swift          Extracts GPS metadata from the PHAsset library in batches
│   ├── GeocodingService.swift          Reverse geocoding with rate limiting + memory cache
│   ├── PhotoStore.swift                @ModelActor — serialized SwiftData reads/writes
│   ├── ContinentMapper.swift           ISO country code → continent lookup
│   ├── StatisticsEngine.swift          Pure [GeoPhoto] → TravelStats transformation
│   └── BackgroundTaskService.swift     BGProcessingTask scheduling and execution
├── ViewModels/
│   ├── AppViewModel.swift              @Observable root state + scan pipeline
│   └── CountryDetailViewModel.swift    PHCachingImageManager for photo grids
├── Views/
│   ├── Onboarding/                     3-page onboarding + permission denied screen
│   ├── Dashboard/                      Map, stats grid, countries + continents carousels, timeline
│   ├── CountryDetail/                  City list + lazy 3-column photo grid
│   ├── ContinentDetail/               Per-continent country list, drills into CountryDetail
│   └── ShareCard/                      4 card types × 4 themes, exported via ImageRenderer
└── Components/
    ├── StatCard.swift                  Reusable metric card
    ├── SectionHeader.swift             Consistent section labels
    ├── PhotoThumbnail.swift            Async PHAsset thumbnail loader
    └── ScanBanner.swift                In-dashboard live scan progress banner
```

Key technical decisions:

| Decision | Reason |
|---|---|
| SwiftData (`@Model` + `@ModelActor`) for persistence | Each photo is its own SQLite row, so geocoding is written incrementally — no whole-file rewrite that could clobber progress on an abrupt exit |
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| Archived `PHPhotoLibrary` change token | A stable, comparable token (base64 of the archived token, not `.description`) reliably skips re-enumerating an unchanged library on launch |
| CLGeocoder rate limiting (1 req/s) | Apple enforces a geocoding rate limit; exceeding it silently returns errors |
| Rounded coordinate cache key | Photos taken in the same area share a geocoding result, reducing API calls by ~80% |
| `BGProcessingTask` (not `BGAppRefreshTask`) | Geocoding can run for tens of minutes on large libraries; `BGAppRefreshTask` has a 30s limit |
| Geocode result persisted per photo (`onResult` awaited) | Each lookup is saved to its row before the next begins, so a cancelled, killed, or expired session resumes exactly where it left off — no double-geocoding |
| Foreground task cancelled on `.background` scene phase | Lets the OS-managed `BGProcessingTask` take over cleanly without two competing scans |
| Scan-generation guard on progress callbacks | A superseded scan's in-flight callbacks are discarded, preventing stale updates from corrupting a newer scan's state |
| Stats recomputed incrementally during scan | Map and stats populate live as photos are processed rather than all at once at the end |
| `PBXFileSystemSynchronizedRootGroup` | Xcode 16 folder sync — new Swift files are picked up automatically without editing the pbxproj |

## Scanning flow

```
App launch
    └── Permission granted
            └── Show dashboard immediately (stats from the SwiftData store if available)
                    └── Foreground Task: enumerate-if-changed → insert new rows → geocode pending rows
                            │   (each geocode result written to its SQLite row immediately)
                            │
                            ├── App stays foreground → completes, banner fades
                            │
                            └── App goes to background
                                    ├── Foreground Task cancelled (all completed rows already persisted)
                                    └── BGProcessingTask scheduled
                                            └── Fires when conditions met (network available)
                                                    └── Resumes geocoding pending rows
                                                            └── App returns to foreground
                                                                    └── Foreground Task resumes
```

## Getting started

1. Clone the repo
2. Open `Photrail.xcodeproj`
3. Select your development team in **Signing & Capabilities**
4. Run on a physical device (photo library access is not available in the Simulator)

> **Note:** To test background task execution during development, use the Xcode debug command:
> ```
> e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.berend.photrail.scan"]
> ```
> Paste this into the Xcode debugger console while the app is paused on a breakpoint after launch.

## License

MIT
