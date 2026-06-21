# Photrail

Photrail automatically turns your photo library into a beautiful travel map. It reads the GPS metadata already embedded in your photos — no manual tagging, no accounts, no cloud.

---

## Features

- **World map** — Interactive map with a pin for every country you've visited
- **Travel statistics** — Countries visited, cities explored, percentage of the world covered, most photographed country
- **Continents overview** — How many of the 6 inhabited continents you've visited, with a per‑continent country list (Antarctica appears as a bonus when visited)
- **Trips** — Photos are grouped into trips (streaks of photos in one country); a gap of about a week starts a new trip
- **Most visited countries** — Countries ranked by number of distinct trips
- **Furthest from home** — Set a home city/country in Settings and see which trip took you furthest away
- **World Wonders & Landmarks** — Detects, by location, which of the New 7 Wonders and other famous landmarks you've photographed; tap any to see your photos of it
- **New‑country notifications** — When a photo taken *today* is your first ever in a country, you get a "Welcome to …" notification (works in the background)
- **Monthly activity timeline** — Bar chart of your photo activity over time
- **Country detail view** — Trips, city breakdown, and a photo grid per country
- **Shareable cards** — Export stat cards (countries, world %, top country, wonders, year recap) in four themes via the native share sheet
- **Home‑screen widgets** — A travel‑stats widget and a world‑wonders widget (small / medium)
- **Durable, resumable processing** — Every result is persisted to a local SwiftData store as it completes, so closing or killing the app never loses progress

## Privacy

- No backend, no accounts, no analytics
- **Country, continent, wonder and trip detection run 100% on‑device** using a bundled map of country borders — no network, no third‑party service
- City names are the only thing resolved online (via Apple's `CLGeocoder`); only coordinates are sent, and only for the optional city‑enrichment pass
- Image data is only loaded when displaying thumbnails; all travel data lives in a local on‑device SwiftData database
- Photo library access can be revoked at any time in Settings

## Requirements

- iOS 18+
- Xcode 16+

## Architecture

Clean MVVM with Swift Concurrency throughout. Persistence is SwiftData (SQLite); all services are actors.

```
Photrail/
├── App/
│   └── RootView.swift                  State machine: onboarding → dashboard
├── Models/
│   ├── GeoPhoto.swift                  Lightweight Sendable photo DTO
│   ├── StoredPhoto.swift               SwiftData @Model — one SQLite row per photo
│   ├── CountryStat.swift               Aggregated country stats (+ trip count, coordinate)
│   ├── ContinentStat.swift             Continent enum + per-continent aggregation
│   ├── Wonder.swift                    Wonder/landmark + per-site match radius & category
│   ├── Trip.swift                      A streak of photos in one country
│   └── TravelStats.swift              Full stats snapshot + widget snapshot + mocks
├── Services/
│   ├── PhotoScanService.swift          Extracts GPS metadata from PHAsset library
│   ├── OfflineCountryGeocoder.swift    On-device coordinate → country (bundled GeoJSON)
│   ├── GeocodingService.swift          City names via CLGeocoder (rate-limited, cached)
│   ├── PhotoStore.swift                @ModelActor — serialized SwiftData access
│   ├── ContinentMapper.swift           ISO country code → continent
│   ├── WonderCatalog.swift             Static catalog of wonders & landmarks
│   ├── WonderDetector.swift            Location-based wonder matching (image-recog ready)
│   ├── TripDetector.swift              Groups photos into trips by country + time gap
│   ├── StatisticsEngine.swift          Pure [GeoPhoto] → TravelStats transformation
│   ├── NotificationService.swift       Local "new country" notifications
│   └── BackgroundTaskService.swift     BGProcessingTask scheduling and execution
├── ViewModels/
│   ├── AppViewModel.swift              @Observable root state + scan pipeline
│   └── CountryDetailViewModel.swift    PHCachingImageManager for photo grids
├── Views/
│   ├── Onboarding/                     Onboarding + permission denied screen
│   ├── Dashboard/                      Map, stats, countries, continents, wonders,
│   │                                   most-visited, furthest-from-home, timeline
│   ├── CountryDetail/                  Trips + city list + lazy photo grid
│   ├── ContinentDetail/               Per-continent country list
│   ├── Wonders/                        Wonders & landmarks list + per-wonder photo grid
│   ├── Settings/                       Home city/country picker + reindex
│   └── ShareCard/                      Shareable stat cards (5 types × 4 themes)
├── Components/                         StatCard, SectionHeader, PhotoThumbnail, ScanBanner
└── Shared/
    └── WidgetSharedStats.swift         App Group snapshot (member of app + widget targets)

PhotrailWidgets/                        Widget extension (Travel Stats + World Wonders)
```

### Key technical decisions

| Decision | Reason |
|---|---|
| Offline country resolution (bundled GeoJSON + point-in-polygon) | Instant, private, no rate limit, no third-party TOS; only city names need the network |
| Two-pass scan (countries → cities) | Core features (countries/continents/wonders/map) complete in seconds; cities enrich after |
| SwiftData (`@Model` + `@ModelActor`) | Per-photo row upserts — geocoding is written incrementally and survives an abrupt exit |
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| Archived `PHPhotoLibrary` change token | Reliably skips re-enumerating an unchanged library on launch |
| CLGeocoder throttled only on cache miss | Cities resolve at ~1 req/s; cache hits and all country work are instant |
| `BGProcessingTask` (not `BGAppRefreshTask`) | City geocoding can run for minutes on large libraries; refresh tasks cap at ~30s |
| Country dataset version flag | Bumping it silently re-resolves all photos' countries when the boundary data improves |
| Scan-generation guard on callbacks | A superseded scan's in-flight callbacks are discarded |
| Self-healing ModelContainer | The store is a rebuildable cache; on a migration failure it's wiped and recreated, never crashing |

## Scanning flow

```
App launch
    └── Permission granted → show dashboard (stats from the store if available)
            └── Enumerate library if changed → insert new photo rows
                    └── (If boundary dataset version changed: silently re-resolve all countries)
                    └── Resolve countries OFFLINE for new photos        → core features appear
                            └── fires "new country" notifications, publishes widgets
                    └── Resolve cities via CLGeocoder (rate-limited)     → city lists fill in
                            │  each result persisted row-by-row → fully resumable
                            └── App backgrounded → BGProcessingTask resumes the city pass
```

## Getting started

1. Clone the repo and open `Photrail.xcodeproj`.
2. **Widgets (optional):** the project includes a `PhotrailWidgets` extension. Both the app and the widget target must have the **App Group** `group.com.berend.photrail` enabled (Signing & Capabilities). The shared snapshot is published there after each scan.
3. Select your team in **Signing & Capabilities** and run on a **physical device** (photo library + geocoding are unreliable in the Simulator).

> The country boundary dataset (`Photrail/countries.geojson`, Natural Earth 1:10m, public domain) is committed to the repo and bundles automatically — no setup needed. If you swap in a different dataset, bump `AppViewModel.countryDatasetVersion` so existing installs re-resolve their countries.

> Run the **`Photrail`** scheme — not `PhotrailWidgets`. Running the widget scheme directly requires an `_XCWidgetKind` environment variable to pick a widget.

> **Test background execution** with the Xcode debugger paused after launch:
> ```
> e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.berend.photrail.scan"]
> ```

## Settings

- **Home** — pick a country and optionally a city; used to compute the furthest trip.
- **Reindex photo library** — rebuilds travel history from scratch. Use it after changing the location or date of photos that were already scanned (a normal incremental scan keeps the original data because the asset id is unchanged).

## License

MIT
