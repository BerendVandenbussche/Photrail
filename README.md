# Photrail

Photrail automatically turns your photo library into a beautiful travel map. It reads the GPS metadata already embedded in your photos — no manual tagging, no accounts, no cloud.

---

## Features

- **World map** — Interactive map with a pin for every country you've visited
- **Travel statistics** — Countries visited, cities explored, percentage of the world covered, most photographed country
- **Continents overview** — How many of the 6 inhabited continents you've visited, with a per‑continent country list (Antarctica appears as a bonus when visited)
- **Trips** — Photos are grouped into trips: a continuous journey away from home that can **span several countries**. A trip ends when you return to your home town (within 50 km of home) or after a gap of more than a week — unless the next photo is in the same country within ~30 days (so a long single‑country stay isn't split). A country's "trip count" is how many trips included it
- **Trip detail** — Tap any trip for a dedicated page: a Vision‑curated hero cover photo, a MapKit map with a numbered pin per city joined by a line in visit order, a key‑stats row (distance traveled, duration, countries, cities, photos, highest point), an itinerary (with per‑stop flags across borders), wonders & landmarks seen on that trip, and the trip's photos — with a live share‑card preview before sharing
- **Manual countries** — Deleted the photos for a trip? Add a country by hand (Places → Countries) so your map and stats stay accurate. Manual entries count toward totals and appear on the map, but can't produce photo‑based share cards
- **On This Day** — Resurfaces photos taken on today's calendar day in past years ("5 years ago · 🇵🇹 Lisbon"), away from home; tap to see that day's photos. Excludes everyday photos within 50 km of home
- **Full‑screen photo viewer** — Tap any photo in a country or trip to open it full‑screen with pinch / double‑tap zoom
- **Most visited countries** — Countries ranked by number of distinct trips
- **Furthest from home** — Set a home city/country in Settings and see which trip took you furthest away
- **World Wonders & Landmarks** — Detects, by location, which of the New 7 Wonders and other famous landmarks you've photographed; tap any to see your photos of it
- **Travel Personality** — An on‑device profile of your travel style (Urban / Coastal / Mountain / Nature / Culture / Transit / Adventure) as percentages, with a dominant type. Daily‑life photos within 50 km of home are excluded so the profile reflects travel
- **Me tab** — A profile page with an emoji avatar, your lifetime snapshot, travel personality, home location, reindex, and the Recaps archive
- **Year in Travel recap** — A paged, Spotify‑Wrapped‑style story (distance with relatable comparisons, most‑photographed country, chronological route map, first‑ever‑visited countries, personality, wonders & landmarks seen, biggest trip, highest peak, superlatives, Vision‑curated "best shots", year summary, hero finale). **Every slide is individually shareable** as its own branded card; the finale also exports light / dark / transparent themes. The finale shows a year‑specific stat set (new countries, highest peak, distance) and a labelled **Travel Score** tier (Getaway → Wanderer → Explorer → Adventurer → Globetrotter)
- **Vision‑curated best shots** — On‑device image aesthetics + scene classification pick the year's most beautiful photos, matched to your personality and time‑spaced, skipping screenshots and people/pet shots
- **New‑country notifications** — When a photo taken *today* is your first ever in a country, you get a "Welcome to …" notification (works in the background)
- **Monthly activity timeline** — Bar chart of your photo activity over time
- **Premium share system** — Multiple card templates (Personality, Summary, Wonders, Trip) plus the Year Recap cards, with map / transparent / photo backgrounds, exported at Instagram‑story resolution (1080×1920) with Photrail branding
- **Home‑screen widgets** — A travel‑stats widget and a world‑wonders widget (small / medium / lock‑screen)
- **Durable, resumable processing** — Every result is persisted to a local SwiftData store as it completes, so closing or killing the app never loses progress

## Privacy

- No backend, no accounts, no analytics
- **Country, continent, coastline, city‑remoteness, wonder, trip, "On This Day" and personality detection all run 100% on‑device** using bundled geographic datasets — no network, no third‑party service
- City **names** are the only thing resolved online (via Apple's `CLGeocoder`); only coordinates are sent, and only for the optional city‑enrichment pass
- Image data is only loaded when displaying thumbnails; all travel data lives in a local on‑device SwiftData database
- Photo library access is **read‑only** and can be revoked at any time in Settings
- Ships an Apple **privacy manifest** (`PrivacyInfo.xcprivacy`, app + widget): no tracking, no data collected, `UserDefaults` declared with reason `CA92.1`. App Store privacy label is **Data Not Collected**

## Requirements

- iOS 18+
- Xcode 16+

## Architecture

Clean MVVM with Swift Concurrency throughout. Persistence is SwiftData (SQLite); all services are actors; scoring engines are pure and unit‑tested.

```
Photrail/
├── App/
│   ├── RootView.swift                  State machine: onboarding → tabs
│   └── MainTabView.swift               Tab bar: Today · Map · Places · Me
├── Models/
│   ├── GeoPhoto.swift                  Lightweight Sendable photo DTO
│   ├── StoredPhoto.swift               SwiftData @Model — one SQLite row per photo
│   ├── CountryStat.swift               Aggregated country stats (+ trip count, coordinate)
│   ├── ContinentStat.swift             Continent enum + per-continent aggregation
│   ├── Wonder.swift                    Wonder/landmark + per-site match radius & category
│   ├── Trip.swift                      A journey away from home (multi-country; primary +
│   │                                   countries, stops, route distance, altitude, wonders)
│   ├── ManualCountry.swift             A hand-added, photo-less country (keeps stats accurate)
│   ├── Memory.swift                    An "On This Day" memory (past-year photos for today)
│   └── TravelStats.swift              Full stats snapshot + widget snapshot + mocks
├── Services/
│   ├── PhotoScanService.swift          Extracts GPS metadata from PHAsset library
│   ├── OfflineCountryGeocoder.swift    On-device coordinate → country (bundled GeoJSON)
│   ├── OfflineCoastline.swift          On-device distance to nearest coast (bundled GeoJSON)
│   ├── OfflinePlaces.swift             On-device distance to nearest city (bundled GeoJSON)
│   ├── PhotoCurator.swift              Vision aesthetics + scene classification → best shots
│   ├── GeocodingService.swift          City names via CLGeocoder (rate-limited, cached)
│   ├── PhotoStore.swift                @ModelActor — serialized SwiftData access
│   ├── ContinentMapper.swift           ISO country code → continent
│   ├── WonderCatalog.swift             Static catalog of wonders & landmarks
│   ├── WonderDetector.swift            Location-based wonder matching (image-recog ready)
│   ├── TripDetector.swift              Groups photos into multi-country journeys (home-town
│   │                                   + time-gap boundaries); builds stops, route, wonders
│   ├── CountryCatalog.swift            All countries (name + flag) for manual entry
│   ├── StatisticsEngine.swift          Pure [GeoPhoto] → TravelStats transformation
│   ├── MemoriesEngine.swift            Pure [GeoPhoto] → "On This Day" memories
│   ├── NotificationService.swift       Local "new country" notifications
│   ├── BackgroundTaskService.swift     BGProcessingTask scheduling and execution
│   ├── TravelPersonality/              Pure scoring engine (category → score → profile)
│   ├── Recap/                          Year recap model, travel title + travel score
│   └── Sharing/                        Share cards (templates, recap, collage, trip), renderer, presenter
├── ViewModels/
│   ├── AppViewModel.swift              @Observable root state + scan pipeline
│   └── CountryDetailViewModel.swift    PHCachingImageManager for photo grids
├── Views/
│   ├── Onboarding/                     Onboarding + permission denied screen
│   ├── Dashboard/                      Today feed: mini-map peek, On This Day, recap entry,
│   │                                   stat strip, highlights, recent trips
│   ├── Map/                            Map tab: full-screen world map (pin → country)
│   ├── Places/                         Places tab: segmented catalog (Countries/Trips/
│   │                                   Continents/Wonders) + manual country picker + activity
│   ├── CountryDetail/                  Mini map + collapsible trips/cities + lazy photo grid
│   │                                   + full-screen zoomable photo viewer
│   ├── TripDetail/                     Hero cover + trip map + stats + itinerary + wonders
│   │                                   + photos + share-card preview
│   ├── ContinentDetail/               Per-continent country list
│   ├── Wonders/                        Wonders & landmarks list + mini map + photo grid
│   ├── Recap/                          Multi-slide Year in Travel story + hero finale
│   ├── Profile/                        Me tab: avatar, personality, home, reindex, recaps
│   └── ShareCard/                      Share composer (templates + backgrounds)
├── Components/                         StatCard, SectionHeader, PhotoThumbnail, ScanBanner,
│                                       LogoView (brand mark), MiniMapDots, JourneyMapView,
│                                       TripMapView (pins + route line), LocationMiniMap,
│                                       FlowLayout, CardStyle (shared card modifier)
└── Shared/
    └── WidgetSharedStats.swift         App Group snapshot (member of app + widget targets)

PhotrailWidgets/                        Widget extension (Travel Stats + World Wonders)
```

### Key technical decisions

| Decision | Reason |
|---|---|
| Offline geocoding (country / coastline / places GeoJSON + point-in-polygon / nearest-point) | Instant, private, no rate limit, no third-party TOS; only city *names* need the network |
| Multi-country trips (home-town + time-gap boundaries) | Models real journeys — a Euro-trip is one trip across countries, not several; domestic trips far from home still count |
| Two-pass scan (countries offline → cities online) | Core features complete in seconds; city names enrich after |
| SwiftData (`@Model` + `@ModelActor`) | Per-photo row upserts — geocoding is written incrementally and survives an abrupt exit |
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| Archived `PHPhotoLibrary` change token | Reliably skips re-enumerating an unchanged library on launch |
| CLGeocoder throttled only on cache miss | Cities resolve at ~1 req/s; cache hits and all offline work are instant |
| `BGProcessingTask` (not `BGAppRefreshTask`) | City geocoding can run for minutes on large libraries; refresh tasks cap at ~30s |
| Dataset version flags | Bumping `countryDatasetVersion` / the personality signature silently re-resolves when data or scoring logic improves |
| Pure scoring engines (personality, score, title) | Decoupled from SwiftUI, deterministic, unit-tested |
| EXIF altitude captured at scan | Drives the Mountain personality and the recap's highest-peak slide, no dataset needed |
| Vision best-shots (aesthetics + classification) | On-device curation of the recap's photo collage; matched to personality, time-spaced, skips people/pets/screenshots |
| High-res image requests (network allowed) | Optimized-Storage libraries fetch full-res originals from iCloud instead of blurry local thumbnails |
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
            └── Enumerate library if changed → insert new photo rows (with GPS + altitude)
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

## Me tab

- **Avatar** — pick an emoji as your profile picture.
- **Travel personality** + lifetime snapshot (countries / cities / continents / trips).
- **Home** — pick a country and optionally a city. Used for the furthest‑trip calculation, as the trip‑detection boundary (a photo within 50 km of home ends a trip), and to exclude everyday photos within 50 km of home from your travel personality.
- **Reindex photo library** — rebuilds travel history from scratch. Use it after changing the location or date of photos that were already scanned (a normal incremental scan keeps the original data because the asset id is unchanged), or to backfill altitude onto previously scanned photos.
- **Recaps** — archive of every year with travel; the current year also has a dedicated entry on the dashboard.

## Testing

`⌘U` runs the unit tests, including the travel personality scoring engine (`PhotrailTests/TravelPersonalityEngineTests.swift`): urban/nature/culture/transit classification, the home‑radius exclusion, percentage normalization, and confidence scaling.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).
