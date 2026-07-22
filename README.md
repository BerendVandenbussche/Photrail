<div align="center">

<img src=".github/assets/banner.svg" alt="Photrail — Your travel history, automatically." width="100%" />

<br />

**Your travel history, automatically.**

Photrail turns your photo library into a beautiful travel map. It reads the GPS metadata already embedded in your photos — no manual tagging, no accounts, no cloud.

![Platform](https://img.shields.io/badge/platform-iOS%2018%2B-0b0e1f?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-SwiftUI-4f45e6?style=flat-square&logo=swift&logoColor=white)
![Privacy](https://img.shields.io/badge/privacy-100%25%20on--device-8c4dd9?style=flat-square)
![License](https://img.shields.io/badge/license-GPLv3-a3a6ff?style=flat-square)
[![Website](https://img.shields.io/badge/website-photrail.berendvandenbussche.be-38216b?style=flat-square)](https://photrail.berendvandenbussche.be)

</div>

---

> **Contributing?** This README is written for you. Start with [Quick start](#quick-start) to get it running, then [How it works](#how-it-works) and [Architecture](#architecture) for the mental model. [Conventions](#contributing) covers the house rules (pure engines, localize everything, versioning). Issues and PRs welcome.

## Contents

- [Quick start](#quick-start)
- [How it works](#how-it-works) — scanning pipeline · trip detection · datasets
- [Project structure](#project-structure)
- [Architecture](#architecture) — principles · key decisions
- [Testing](#testing)
- [Localization](#localization)
- [Privacy](#privacy)
- [Contributing](#contributing) — conventions · versioning
- [What it does](#what-it-does) — feature reference
- [License](#license)

## Quick start

**Requirements:** iOS 18+, Xcode 16+.

1. Clone the repo and open `Photrail.xcodeproj`.
2. Select your team in **Signing & Capabilities** and run the **`Photrail`** scheme on a **physical device** — the photo library and geocoding are unreliable in the Simulator.
3. The geographic datasets are committed and bundle automatically — no setup needed.

Optional capabilities (the app runs fine without either):

- **Widgets** — the app and the `PhotrailWidgets` target both need the **App Group** `group.com.berend.photrail`. The shared stats snapshot is published there after each scan. Run the `Photrail` scheme, not `PhotrailWidgets` (running the widget scheme directly needs an `_XCWidgetKind` env var).
- **Trip Insights (Apple Health)** — the app target needs the **HealthKit** capability. The entitlement is already in `Photrail/Photrail.entitlements`; confirm it shows in Signing & Capabilities and let automatic signing regenerate the profile. It's opt-in at runtime.

<details>
<summary>Testing background execution</summary>

With the Xcode debugger paused after launch:

```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.berend.photrail.scan"]
```
</details>

## How it works

Photrail is a pipeline: **photos → GPS → offline geocoding → stats/trips/personality → UI**. Everything runs on-device; only city *names* touch the network.

### Scanning pipeline

```
App launch
    └── Permission granted → show dashboard (stats from the store if available)
            └── Enumerate library if changed → insert new photo rows (GPS + altitude)
                    └── (Boundary dataset version changed? → silently re-resolve all countries)
                    └── Resolve countries OFFLINE for new photos        → core features appear
                            └── fires "new country" notifications, publishes widgets
                    └── Resolve cities via CLGeocoder (rate-limited)     → city lists fill in
                            │  each result persisted row-by-row → fully resumable
                            └── App backgrounded → BGProcessingTask resumes the city pass
            └── Personality profile recomputed off-main and cached (home photos excluded;
                    Health signals folded in per trip when Trip Insights is enabled)

Trip Insights (opt-in, lazy — computed when a trip is opened, never during the scan)
    └── Enable from a trip / the Me tab → read-only Health permission sheet
            └── Query the trip's date window (heart rate, flights, energy, steps, workouts)
                    └── TravelInsightsEngine assembles the result (pure)
                            └── cached in TripInsightsStore, keyed by trip id + photo signature
```

Every result is persisted to a local SwiftData store as it completes, so closing or killing the app never loses progress. A two-pass design (countries offline, then cities online) means the core features appear in seconds and city names enrich after.

### Trip detection

`TripDetector` groups photos, in time order, into trips — a continuous journey away from home that can **span several countries**. A trip ends when:

- **You're back in your home country** — any photo in `homeCountryCode` ends the trip (also a photo within `homeRadiusKm` of a set home city). A journey is time spent *abroad*.
- **The next photo is unlikely to belong to the same journey** — scored by a **same-trip probability** rather than a flat time cutoff. It weighs the distance between the two places, whether they share a continent, the size of the time gap, and whether *home sits between them* (a natural round trip). A short hop stays in one trip even across a border; a quick flight back through home splits into two.

Two inputs are cleaned out **before** grouping so they can't corrupt a trip:

- **GPS spikes** — a photo thousands of km from *both* neighbours while those neighbours are close together (a screenshot, a saved/received image, or a location that defaulted to home) is dropped.
- **Airport transit** — a photo taken at a major international hub (`AirportCatalog`) is treated as a layover, so a stopover country never joins the trip (no "Germany + Brazil" for a Brazil holiday).

Both are excluded from *trip grouping* only; the photos still count toward overall country/city stats.

### Bundled datasets

Committed under `Photrail/` and bundled automatically (Natural Earth, public domain):

| File | Source | Purpose |
|---|---|---|
| `countries.geojson` | `ne_10m_admin_0_countries` | coordinate → country |
| `coastline.geojson` | `ne_50m_coastline` | distance to nearest coast (Coastal personality) |
| `places.geojson` | `ne_10m_populated_places_simple` | distance to nearest city (Urban vs. Nature) |

Keep bundled versions lightly simplified (≥30%) — over-simplifying borders misplaces towns near boundaries. When swapping a dataset, bump the relevant version (`AppViewModel.countryDatasetVersion`, or the personality signature) so existing installs recompute.

## Project structure

Clean MVVM with Swift Concurrency throughout. Persistence is SwiftData (SQLite); services are actors; scoring engines are pure and unit-tested.

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
│   ├── TravelStats.swift               Full stats snapshot + widget snapshot + mocks
│   ├── TripInsights.swift              Per-trip HealthKit insights result (cached, Codable)
│   └── HealthMetrics.swift             Insight sub-types (excitement, milestone, food, workout, persona)
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
│   ├── TripDetector.swift              Groups photos into multi-country journeys (home-country
│   │                                   boundary + same-trip probability; spike/airport filtering)
│   ├── AirportCatalog.swift            Major international hubs → layover-transit exclusion
│   ├── CountryCatalog.swift            All countries (name + flag) for manual entry
│   ├── StatisticsEngine.swift          Pure [GeoPhoto] → TravelStats transformation
│   ├── MemoriesEngine.swift            Pure [GeoPhoto] → "On This Day" memories
│   ├── LocalizedCounts.swift           Plural-aware localized count phrases (days/trips/…)
│   ├── TripCalendar.swift              Pure [Trip] → per-day flags for a month
│   ├── TripCoverStore.swift            Caches each trip's curated hero photo
│   ├── NotificationService.swift       Local "new country" notifications
│   ├── BackgroundTaskService.swift     BGProcessingTask scheduling and execution
│   ├── TravelPersonality/              Pure scoring engine (category → score → profile;
│   │                                   optional Health direction folded in per trip)
│   ├── HealthKit/                      Opt-in Insights: HealthKitService (actor, only file
│   │                                   importing HealthKit), TravelInsightsEngine (pure),
│   │                                   TripInsightsStore (cache), PhotoAuthorship (capture guard)
│   ├── Recap/                          Year recap model, travel title + travel score
│   └── Sharing/                        Share cards (templates, recap, collage, trip, calendar), renderer, presenter
├── ViewModels/
│   └── AppViewModel.swift              @Observable root state + scan pipeline
├── Localizable.xcstrings               String Catalog (English + Dutch)
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
│   ├── Insights/                       Trip Insights section, workout-chapter sheet, opt-in prompt
│   ├── Calendar/                       Travel calendar: month grid of trip-day flags + share
│   ├── ContinentDetail/                Per-continent country list
│   ├── Wonders/                        Wonders & landmarks list + mini map + photo grid
│   ├── Recap/                          Multi-slide Year in Travel story + hero finale
│   ├── Profile/                        Me tab: avatar, personality, home, reindex, recaps
│   └── ShareCard/                      Share composer (templates + backgrounds)
├── Components/                         StatCard, SectionHeader, PhotoThumbnail, ScanBanner,
│                                       LogoView (brand mark), MiniMapDots, JourneyMapView,
│                                       TripMapView (pins + route line), LocationMiniMap,
│                                       FlowLayout, CardStyle (shared card modifier), FlagCluster,
│                                       DetailHeader, PhotoGridSection, TappablePhotoThumbnail
└── Shared/
    └── WidgetSharedStats.swift         App Group snapshot (member of app + widget targets)

PhotrailWidgets/                        Widget extension (Travel Stats + World Wonders)
                                        + its own Localizable.xcstrings (separate target)

Config/
├── Info.plist                         App Info.plist (usage strings, etc.)
└── Version.xcconfig                   Single source of truth for app + widget versions
```

## Architecture

Guiding principles, and why they hold:

- **Pure scoring engines.** Personality, travel score, title, and insights are plain value-in/value-out types with no SwiftUI or framework dependencies — deterministic and unit-testable.
- **Actors for I/O.** Every service that touches the photo library, SwiftData, or HealthKit is an `actor`, so large libraries process off the main thread without data races.
- **SwiftData as a rebuildable cache.** Per-photo row upserts mean geocoding is written incrementally and survives an abrupt exit; on a migration failure the store is wiped and recreated, never crashing.
- **On-device by default.** Only city names use the network.

### Key decisions

| Decision | Reason |
|---|---|
| Offline geocoding (country / coastline / places GeoJSON + point-in-polygon / nearest-point) | Instant, private, no rate limit, no third-party TOS; only city *names* need the network |
| Multi-country trips scored by same-trip probability (distance, continent, gap, home-between) | Models real journeys — a Euro-trip is one trip across countries; two separate holidays days apart don't merge just because they fall within a week |
| GPS-spike + airport-transit filtering before grouping | A stray home-GPS photo or a layover can't split a trip or inject a transit country; excluded from grouping only, still counted in overall stats |
| Home country (not just a 50 km radius) ends a trip | A journey is time abroad; passing back through your own country — any city — correctly closes the trip |
| Two-pass scan (countries offline → cities online) | Core features complete in seconds; city names enrich after |
| SwiftData (`@Model` + `@ModelActor`) | Per-photo row upserts — geocoding is written incrementally and survives an abrupt exit |
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| Archived `PHPhotoLibrary` change token | Reliably skips re-enumerating an unchanged library on launch |
| CLGeocoder throttled only on cache miss | Cities resolve at ~1 req/s; cache hits and all offline work are instant |
| `BGProcessingTask` (not `BGAppRefreshTask`) | City geocoding can run for minutes on large libraries; refresh tasks cap at ~30s |
| Dataset version flags | Bumping `countryDatasetVersion` / the personality signature silently re-resolves when data or scoring logic improves |
| Pure scoring engines (personality, score, title, insights) | Decoupled from SwiftUI, deterministic, unit-tested |
| HealthKit isolated behind one `actor`; `TravelInsightsEngine` stays pure | Only `HealthKitService` imports HealthKit; the engine takes raw sample arrays, so all insight logic is unit-testable without entitlements or a device |
| Per-trip insights cached (`TripInsightsStore`, keyed by trip id + photo signature) | HealthKit queries are slow; compute once and reuse — the Insights UI and the personality tilt share the same cache |
| Photo authorship by capture heuristics, not device identity | EXIF device model can't tell your iPhone from a friend's and is meaningless after an upgrade/transfer; ruling out screenshots/shared/messaging files keeps biometrics off photos you didn't take |
| Health folds into personality as a per-trip *direction*, scaled to photo evidence | Lets climbs/steps/workouts shift a trip's flavour without overwhelming the photos; gated on the Insights opt-in and degrades to photo-only |
| EXIF altitude captured at scan | Drives the Mountain personality and the recap's highest-peak slide, no dataset needed |
| Vision best-shots (aesthetics + classification) | On-device curation of the recap's photo collage; matched to personality, time-spaced, skips people/pets/screenshots |
| High-res image requests (network allowed) | Optimized-Storage libraries fetch full-res originals from iCloud instead of blurry local thumbnails |
| Self-healing ModelContainer | The store is a rebuildable cache; on a migration failure it's wiped and recreated, never crashing |

## Testing

`⌘U` runs the unit tests. Because the scoring engines are pure, most logic is testable with no device or entitlements:

- **Trip detection** (`PhotrailTests/TripDetectorTests.swift`): same-trip probability, home-country boundary, GPS-spike rejection, airport-layover exclusion, border-town hops, and fast-trip-through-home splits.
- **Travel personality** (`PhotrailTests/TravelPersonalityEngineTests.swift`): classification, home-radius exclusion, percentage normalization, confidence scaling.
- **Trip Insights** (`PhotrailTests/TravelInsightsEngineTests.swift`): elevation-milestone selection, food-equivalent math, persona thresholds, heart-rate-to-photo matching, workout grouping, the photo-authorship filename heuristic, and the Health→personality direction vectors.

> Trip Insights' on-device UI can't be exercised in unit tests — it needs the HealthKit capability and a device (or a simulator seeded with Health data). The pure engine is fully covered.

## Localization

Photrail ships in **English** and **Dutch (Flemish)** via **String Catalogs** (`.xcstrings`). The app and widget each have their own catalog (separate targets). iOS picks the language from the device; users can override per-app in **Settings → Photrail → Language**.

Conventions:

- SwiftUI `Text("literal")` / `.navigationTitle("…")` localize automatically. Strings passed through reusable components use `LocalizedStringKey`; strings built in code use `String(localized:)`.
- **Counts** go through `LocalizedCounts` (`L.days`, `L.trips`, …) for grammatically correct plurals.
- **Country names and dates** come from the system (`Locale` / `DateFormatter`). **City names** are data and stay as captured.
- **Shareable cards stay English by design** (international audience): each card forces `\.environment(\.locale, "en_US")` and uses the English-only helpers (`Trip.englishDisplayName`, `TravelCategory.englishTitle`, `Trip.englishDateRange`, `TravelTitle` / `TravelScore.tier`).

**Adding a language:** add it under **Project → Info → Localizations**, then fill the new column in each `Localizable.xcstrings`. Untranslated keys fall back to English.

## Privacy

- No backend, no accounts, no analytics.
- **Country, continent, coastline, city-remoteness, wonder, trip, "On This Day" and personality detection all run 100% on-device** using bundled datasets — no network, no third party.
- City **names** are the only thing resolved online (Apple's `CLGeocoder`); only coordinates are sent, and only for the optional city-enrichment pass.
- **Apple Health** (Trip Insights) is **opt-in and read-only**, queried entirely on-device; nothing is written back and no health data leaves the phone. Revocable in the Health app / Settings.
- Image data is only loaded when displaying thumbnails; all travel data lives in a local SwiftData database. Photo library access is **read-only** and revocable anytime.
- Ships an Apple **privacy manifest** (`PrivacyInfo.xcprivacy`, app + widget): no tracking, no data collected, `UserDefaults` declared with reason `CA92.1`. App Store label: **Data Not Collected**.

## Contributing

Issues and pull requests are welcome. A few house rules that keep the codebase consistent:

- **Keep scoring logic in pure engines.** New analysis (a stat, a personality signal, an insight) should be a pure function/type in `Services/…`, with a unit test — not logic baked into a view or a service that does I/O.
- **Isolate side effects in actors.** Anything touching Photos, SwiftData, HealthKit, or the network belongs in an `actor` service.
- **Localize new user-facing strings** (English + Dutch) in the right catalog. Remember shareable cards stay English.
- **Add tests** for engine changes — `TripDetectorTests`, `TravelPersonalityEngineTests`, `TravelInsightsEngineTests` are the patterns to follow.
- **Run on a device.** Photos + geocoding don't work well in the Simulator.
- **Extending the airport list:** add hub coordinates to `AirportCatalog.hubs` — it only needs the international connecting hubs where layovers happen, not every airstrip.
- **When scoring/data logic changes,** bump the relevant version flag (`AppViewModel.countryDatasetVersion` or the personality signature) so existing installs recompute.

### Versioning

App and widget versions come from a single file — **`Config/Version.xcconfig`**:

```
MARKETING_VERSION = 2.0.1
CURRENT_PROJECT_VERSION = 4
```

Both targets inherit these (no per-target overrides), so the app and its extension can never drift and Apple's "extension version must match the app" check always passes. **Bump these two lines to cut a release.**

## What it does

<details>
<summary><strong>Feature reference</strong> (click to expand)</summary>

**Map & stats**
- **World map** — a pin for every country visited.
- **Travel statistics** — countries, cities, % of the world covered, most-photographed country.
- **Continents overview** — inhabited continents visited, per-continent country list (Antarctica is a bonus).
- **Most visited countries** — ranked by distinct trips.
- **Furthest from home** — set a home city/country; see which trip took you furthest.
- **Monthly activity timeline** — bar chart of photo activity over time.

**Trips**
- **Trips** — continuous journeys away from home that can span countries (see [Trip detection](#trip-detection)). A country's "trip count" is how many trips included it.
- **Custom trip names** — rename any trip; the name replaces the country list everywhere and can be reset.
- **Trip detail** — Vision-curated hero cover, MapKit route with a numbered pin per city, key stats (distance, duration, countries, cities, photos, highest point), an itinerary with per-stop flags, wonders seen, the trip's photos, and a live share-card preview.
- **Manual countries** — deleted a trip's photos? Add a country by hand so the map/stats stay accurate (no photo-based cards).

**Discovery**
- **On This Day** — resurfaces photos from today's date in past years, away from home.
- **Travel Calendar** — a month grid with a flag on every trip day; share a month as a card.
- **World Wonders & Landmarks** — detects by location which of the New 7 Wonders and other landmarks you've photographed; progress card + per-country list.
- **Full-screen photo viewer** — pinch / double-tap zoom.

**Personality & Health**
- **Travel Personality** — an on-device profile (Urban / Coastal / Mountain / Nature / Culture / Transit / Adventure) with a dominant type; home photos excluded. When Trip Insights is on, each trip's Health signals gently tilt its flavour.
- **Trip Insights (Apple Health)** — optional, opt-in, on-device. Per trip: **Excitement Meter** (heart rate → per-photo vibe badge), **Vertical Exploration** (flights climbed → landmark milestones), **Travel Fuel** (active energy → local food equivalents), **Workout Chapters** (`HKWorkout` overlapping the trip → sub-album with route + stats), **Travel Persona** (steps/pace vs. photo volume → an archetype). Read-only; degrades gracefully.
- **Photo authorship guard** — the Excitement Meter only badges photos you likely took yourself (rules out screenshots, shared/synced, messaging files) — no fragile device-identity checks.

**Recap & sharing**
- **Year in Travel recap** — a paged, Wrapped-style story (distance, most-photographed country, route map, first-visited countries, personality, wonders, biggest trip, highest peak, superlatives, Vision best shots, hero finale). Every slide is individually shareable; the finale exports light/dark/transparent and shows a **Travel Score** tier.
- **Vision-curated best shots** — on-device aesthetics + scene classification pick the year's most beautiful photos, matched to personality and time-spaced.
- **Premium share system** — card templates (Personality, Summary, Wonders, Trip) + recap cards, map/transparent/photo backgrounds, 1080×1920 with branding.

**Platform**
- **Me tab** — emoji avatar, lifetime snapshot, personality, home location, Trip Insights toggle, reindex, Travel Calendar, Recaps archive.
- **New-country notifications** — a "Welcome to …" notification when a photo taken *today* is your first ever in a country (works in the background).
- **Home-screen widgets** — travel-stats and world-wonders widgets (small / medium / lock-screen).
- **Localization** — fully localized (English + Dutch).
- **Durable, resumable processing** — every result persisted as it completes; closing the app never loses progress.

</details>

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

---

<div align="center">

<img src=".github/assets/logo.svg" alt="Photrail" width="52" />

**Photrail** — Your travel history, automatically.

[photrail.berendvandenbussche.be](https://photrail.berendvandenbussche.be)

</div>
