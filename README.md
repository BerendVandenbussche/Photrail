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
- **Travel Personality** — An on‑device profile of your travel style (Urban / Coastal / Mountain / Nature / Culture / Transit / Adventure) as percentages, with a dominant type
- **Year in Travel recap** — A paged, Spotify‑Wrapped‑style story for any year ending in a shareable "snapshot" finale, plus a Past Years archive on the homepage
- **New‑country notifications** — When a photo taken *today* is your first ever in a country, you get a "Welcome to …" notification (works in the background)
- **Monthly activity timeline** — Bar chart of your photo activity over time
- **Premium share system** — Multiple card templates (Personality, Summary, Wonders, Trip, Year Recap) with map / transparent / photo backgrounds, exported at Instagram‑story resolution (1080×1920) with Photrail branding
- **Home‑screen widgets** — A travel‑stats widget and a world‑wonders widget (small / medium / lock‑screen)
- **Durable, resumable processing** — Every result is persisted to a local SwiftData store as it completes, so closing or killing the app never loses progress

## Privacy

- No backend, no accounts, no analytics
- **Country, continent, coastline, city‑remoteness, wonder, trip and personality detection all run 100% on‑device** using bundled geographic datasets — no network, no third‑party service
- City **names** are the only thing resolved online (via Apple's `CLGeocoder`); only coordinates are sent, and only for the optional city‑enrichment pass
- Image data is only loaded when displaying thumbnails; all travel data lives in a local on‑device SwiftData database
- Photo library access can be revoked at any time in Settings

## Requirements

- iOS 18+
- Xcode 16+

## Architecture

Clean MVVM with Swift Concurrency throughout. Persistence is SwiftData (SQLite); all services are actors; scoring engines are pure and unit‑tested.

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
│   ├── OfflineCoastline.swift          On-device distance to nearest coast (bundled GeoJSON)
│   ├── OfflinePlaces.swift             On-device distance to nearest city (bundled GeoJSON)
│   ├── GeocodingService.swift          City names via CLGeocoder (rate-limited, cached)
│   ├── PhotoStore.swift                @ModelActor — serialized SwiftData access
│   ├── ContinentMapper.swift           ISO country code → continent
│   ├── WonderCatalog.swift             Static catalog of wonders & landmarks
│   ├── WonderDetector.swift            Location-based wonder matching (image-recog ready)
│   ├── TripDetector.swift              Groups photos into trips by country + time gap
│   ├── StatisticsEngine.swift          Pure [GeoPhoto] → TravelStats transformation
│   ├── NotificationService.swift       Local "new country" notifications
│   ├── BackgroundTaskService.swift     BGProcessingTask scheduling and execution
│   ├── TravelPersonality/              Pure scoring engine (category → score → profile)
│   ├── Recap/                          Year recap model, travel title + travel score
│   └── Sharing/                        Share card types, model, renderer, share sheet
├── ViewModels/
│   ├── AppViewModel.swift              @Observable root state + scan pipeline
│   └── CountryDetailViewModel.swift    PHCachingImageManager for photo grids
├── Views/
│   ├── Onboarding/                     Onboarding + permission denied screen
│   ├── Dashboard/                      Map, recap entry, stats, personality, countries,
│   │                                   most-visited, continents, wonders, timeline, past years
│   ├── CountryDetail/                  Trips + city list + lazy photo grid
│   ├── ContinentDetail/               Per-continent country list
│   ├── Wonders/                        Wonders & landmarks list + per-wonder photo grid
│   ├── Recap/                          8-slide Year in Travel story + hero finale
│   ├── Settings/                       Home city/country picker + reindex
│   └── ShareCard/                      Share composer (templates + backgrounds)
├── Components/                         StatCard, SectionHeader, PhotoThumbnail, ScanBanner,
│                                       LogoView (brand mark), MiniMapDots
└── Shared/
    └── WidgetSharedStats.swift         App Group snapshot (member of app + widget targets)

PhotrailWidgets/                        Widget extension (Travel Stats + World Wonders)
```

### Key technical decisions

| Decision | Reason |
|---|---|
| Offline geocoding (country / coastline / places GeoJSON + point-in-polygon / nearest-point) | Instant, private, no rate limit, no third-party TOS; only city *names* need the network |
| Two-pass scan (countries offline → cities online) | Core features complete in seconds; city names enrich after |
| SwiftData (`@Model` + `@ModelActor`) | Per-photo row upserts — geocoding is written incrementally and survives an abrupt exit |
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| Archived `PHPhotoLibrary` change token | Reliably skips re-enumerating an unchanged library on launch |
| CLGeocoder throttled only on cache miss | Cities resolve at ~1 req/s; cache hits and all offline work are instant |
| `BGProcessingTask` (not `BGAppRefreshTask`) | City geocoding can run for minutes on large libraries; refresh tasks cap at ~30s |
| Dataset version flags | Bumping `countryDatasetVersion` / the personality signature silently re-resolves when data or scoring logic improves |
| Pure scoring engines (personality, score, title) | Decoupled from SwiftUI, deterministic, unit-tested |
| Self-healing ModelContainer | The store is a rebuildable cache; on a migration failure it's wiped and recreated, never crashing |

## Bundled datasets

All committed to the repo under `Photrail/` and bundled automatically (Natural Earth, public domain):

| File | Source | Purpose |
|---|---|---|
| `countries.geojson` | `ne_10m_admin_0_countries` | coordinate → country |
| `coastline.geojson` | `ne_50m_coastline` | distance to nearest coast (Coastal personality) |
| `places.geojson` | `ne_10m_populated_places_simple` | distance to nearest city (Urban vs. Nature) |

Keep the bundled versions lightly simplified (≥30%) — over-simplifying borders misplaces towns near boundaries. When you swap in a new dataset, bump the relevant version (`AppViewModel.countryDatasetVersion`, or the personality signature) so existing installs recompute.

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
            └── Personality profile recomputed off-main and cached (home photos excluded)
```

## Branding

A single vector mark (`Components/LogoView.swift`) — a flowing "trail" ending in a location node — is used consistently across the app header, onboarding, share cards, widgets, and the app icon. The icon ships primary / dark / tinted variants (iOS 18 appearances).

## Getting started

1. Clone the repo and open `Photrail.xcodeproj`.
2. **Widgets (optional):** the project includes a `PhotrailWidgets` extension. Both the app and the widget target must have the **App Group** `group.com.berend.photrail` enabled (Signing & Capabilities). The shared snapshot is published there after each scan.
3. Select your team in **Signing & Capabilities** and run on a **physical device** (photo library + geocoding are unreliable in the Simulator).

> The geographic datasets above are committed and bundle automatically — no setup needed.

> Run the **`Photrail`** scheme — not `PhotrailWidgets`. Running the widget scheme directly requires an `_XCWidgetKind` environment variable to pick a widget.

> **Test background execution** with the Xcode debugger paused after launch:
> ```
> e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.berend.photrail.scan"]
> ```

## Settings

- **Home** — pick a country and optionally a city. Used for the furthest‑trip calculation and to exclude everyday photos within 50 km of home from your travel personality.
- **Reindex photo library** — rebuilds travel history from scratch. Use it after changing the location or date of photos that were already scanned (a normal incremental scan keeps the original data because the asset id is unchanged).

## Testing

`⌘U` runs the unit tests, including the travel personality scoring engine (`PhotrailTests/TravelPersonalityEngineTests.swift`): urban/nature/culture/transit classification, the home‑radius exclusion, percentage normalization, and confidence scaling.

## License

MIT
