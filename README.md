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

## Features

- **World map** — Interactive map with a pin for every country you've visited
- **Travel statistics** — Countries visited, cities explored, percentage of the world covered, most photographed country
- **Continents overview** — How many of the 6 inhabited continents you've visited, with a per‑continent country list (Antarctica appears as a bonus when visited)
- **Trips** — Photos are grouped into trips: a continuous journey away from home that can **span several countries**. A trip ends when you return to your home town (within 50 km of home), or when the next photo is unlikely to belong to the same journey. That likelihood is a **same‑trip probability score** — instead of a flat time cutoff, each candidate is weighed by the distance between the two places, whether they share a continent, the size of the time gap, and whether *home sits between them* (a natural round trip). So a Prague weekend and a Canada holiday a few days apart stay **separate**, while a European road trip or a direct long‑haul flight leg stays **whole**. A country's "trip count" is how many trips included it
- **Custom trip names** — Rename any trip (e.g. "Summer in Italy") from its detail page; the name replaces the country list everywhere — lists, detail header, and share cards — and can be reset to the default at any time
- **Trip detail** — Tap any trip for a dedicated page: a Vision‑curated hero cover photo, a MapKit map with a numbered pin per city joined by a line in visit order, a key‑stats row (distance traveled, duration, countries, cities, photos, highest point), an itinerary (with per‑stop flags across borders), wonders & landmarks seen on that trip, and the trip's photos — with a live share‑card preview before sharing
- **Manual countries** — Deleted the photos for a trip? Add a country by hand (Places → Countries) so your map and stats stay accurate. Manual entries count toward totals and appear on the map, but can't produce photo‑based share cards
- **On This Day** — Resurfaces photos taken on today's calendar day in past years ("5 years ago · 🇵🇹 Lisbon"), away from home; tap to see that day's photos. Excludes everyday photos within 50 km of home
- **Travel Calendar** — A month grid (Me tab) with a flag on every day you were on a trip — the right country's flag per day for multi‑country journeys. Tap a day to open that trip; share any month as a branded card
- **World Wonders progress** — A Today‑tab card showing how many of the New 7 Wonders you've photographed ("3 of 7") with a flag row + progress bar, once you've seen at least one; a country's detail page also lists the wonders you've seen there
- **Full‑screen photo viewer** — Tap any photo in a country or trip to open it full‑screen with pinch / double‑tap zoom
- **Most visited countries** — Countries ranked by number of distinct trips
- **Furthest from home** — Set a home city/country in Settings and see which trip took you furthest away
- **World Wonders & Landmarks** — Detects, by location, which of the New 7 Wonders and other famous landmarks you've photographed; tap any to see your photos of it
- **Travel Personality** — An on‑device profile of your travel style (Urban / Coastal / Mountain / Nature / Culture / Transit / Adventure) as percentages, with a dominant type. Daily‑life photos within 50 km of home are excluded so the profile reflects travel. When **Trip Insights** is enabled (below), each trip's Health signals (climbs, steps, workouts) gently tilt its flavour — scaled to that trip's photo evidence so it shifts proportions without overwhelming them, and degrading to photo‑only whenever Health has no data
- **Trip Insights (Apple Health)** — An **optional, opt‑in** module that cross‑references Apple Health with your trip's photos, entirely on‑device. Enable it from any trip (or the Me tab) — a contextual "late opt‑in", so onboarding is untouched. It adds, per trip: an **Excitement Meter** (heart rate matched to the moment each photo was taken → a per‑photo "vibe" badge), **Vertical Exploration** (flights climbed → fun landmark milestones, e.g. "1.4× the Eiffel Tower"), **Travel Fuel** (active energy → locally‑themed food equivalents, e.g. croissants in France), **Workout Chapters** (any `HKWorkout` — including third‑party writes like Strava — whose window overlaps the trip becomes a sub‑album with its route map and stats), and a **Travel Persona** (steps/pace vs. photo volume → an archetype like *The Flâneur* or *The Mission Traveler*). Health is **read‑only**; every field degrades gracefully when data is missing
- **Photo authorship guard** — The Excitement Meter only badges photos you likely **took yourself**. Rather than fragile device‑identity checks (which break when you upgrade/transfer, and can't tell your iPhone from a friend's), it rules out screenshots, shared‑album/synced assets, and messaging‑app filenames — so biometrics are never attributed to a picture someone else took
- **Me tab** — A profile page with an emoji avatar, your lifetime snapshot, travel personality, home location, Trip Insights toggle, reindex, the Travel Calendar, and the Recaps archive
- **Year in Travel recap** — A paged, Spotify‑Wrapped‑style story (distance with relatable comparisons, most‑photographed country, chronological route map, first‑ever‑visited countries, personality, wonders & landmarks seen, biggest trip, highest peak, superlatives, Vision‑curated "best shots", year summary, hero finale). **Every slide is individually shareable** as its own branded card; the finale also exports light / dark / transparent themes. The finale shows a year‑specific stat set (new countries, highest peak, distance) and a labelled **Travel Score** tier (Getaway → Wanderer → Explorer → Adventurer → Globetrotter)
- **Vision‑curated best shots** — On‑device image aesthetics + scene classification pick the year's most beautiful photos, matched to your personality and time‑spaced, skipping screenshots and people/pet shots
- **New‑country notifications** — When a photo taken *today* is your first ever in a country, you get a "Welcome to …" notification (works in the background)
- **Monthly activity timeline** — Bar chart of your photo activity over time
- **Premium share system** — Multiple card templates (Personality, Summary, Wonders, Trip) plus the Year Recap cards, with map / transparent / photo backgrounds, exported at Instagram‑story resolution (1080×1920) with Photrail branding
- **Home‑screen widgets** — A travel‑stats widget and a world‑wonders widget (small / medium / lock‑screen)
- **Localization (i18n)** — Fully localized UI via String Catalogs, currently **English** and **Dutch (Flemish)**. The device/per‑app language decides automatically (Settings → Photrail → Language). Country names and dates localize from the system; plural forms are grammatically correct in each language. Shareable cards stay in English by design (they're built for an international audience)
- **Durable, resumable processing** — Every result is persisted to a local SwiftData store as it completes, so closing or killing the app never loses progress

## Privacy

- No backend, no accounts, no analytics
- **Country, continent, coastline, city‑remoteness, wonder, trip, "On This Day" and personality detection all run 100% on‑device** using bundled geographic datasets — no network, no third‑party service
- City **names** are the only thing resolved online (via Apple's `CLGeocoder`); only coordinates are sent, and only for the optional city‑enrichment pass
- **Apple Health** (Trip Insights) is **opt‑in and read‑only**, queried entirely on‑device; nothing is written back and no health data ever leaves the phone. It's off until you enable it, and revocable in the Health app / Settings
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
│   ├── TravelStats.swift              Full stats snapshot + widget snapshot + mocks
│   ├── TripInsights.swift             Per-trip HealthKit insights result (cached, Codable)
│   └── HealthMetrics.swift            Insight sub-types (excitement, milestone, food, workout, persona)
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
│   │                                   boundary + same-trip probability); builds stops, route, wonders
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
│   ├── ContinentDetail/               Per-continent country list
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
```

### Key technical decisions

| Decision | Reason |
|---|---|
| Offline geocoding (country / coastline / places GeoJSON + point-in-polygon / nearest-point) | Instant, private, no rate limit, no third-party TOS; only city *names* need the network |
| Multi-country trips scored by same-trip probability (distance, continent, gap, home-between) | Models real journeys — a Euro-trip is one trip across countries; but a Prague weekend and a Canada holiday days apart don't merge just because they're within a week |
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
| Health folds into personality as a per-trip *direction*, scaled to photo evidence | Lets climbs/steps/workouts shift a trip's flavour without overwhelming the photos; fully gated on the Insights opt-in and degrades to photo-only |
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
            └── Personality profile recomputed off-main and cached (home photos excluded;
                    Health signals folded in per trip when Trip Insights is enabled)

Trip Insights (opt-in, lazy — computed when a trip is opened, never during the scan)
    └── Enable from a trip / the Me tab → read-only Health permission sheet
            └── Query the trip's date window (heart rate, flights, energy, steps, workouts)
                    └── TravelInsightsEngine assembles the result (pure)
                            └── cached in TripInsightsStore, keyed by trip id + photo signature
```

## Branding

A single vector mark (`Components/LogoView.swift`) — a flowing "trail" ending in a location node — is used consistently across the app header, onboarding, share cards, widgets, and the app icon. The icon ships primary / dark / tinted variants (iOS 18 appearances).

## Getting started

1. Clone the repo and open `Photrail.xcodeproj`.
2. **Widgets (optional):** the project includes a `PhotrailWidgets` extension. Both the app and the widget target must have the **App Group** `group.com.berend.photrail` enabled (Signing & Capabilities). The shared snapshot is published there after each scan.
3. Select your team in **Signing & Capabilities** and run on a **physical device** (photo library + geocoding are unreliable in the Simulator).
4. **Trip Insights (optional):** the app target needs the **HealthKit** capability (Signing & Capabilities) — the entitlement is already in `Photrail/Photrail.entitlements`, so confirm it's shown and let automatic signing regenerate the profile. The feature is opt‑in at runtime; without Health access the rest of the app is unaffected.

> The geographic datasets above are committed and bundle automatically — no setup needed.

> Run the **`Photrail`** scheme — not `PhotrailWidgets`. Running the widget scheme directly requires an `_XCWidgetKind` environment variable to pick a widget.

> **Test background execution** with the Xcode debugger paused after launch:
> ```
> e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.berend.photrail.scan"]
> ```

## Me tab

- **Avatar** — pick an emoji as your profile picture.
- **Travel personality** + lifetime snapshot (countries / cities / continents / trips).
- **Trip Insights** — a toggle for the optional Apple Health module (heart rate, climbs, energy, workouts, personas). Off by default; flipping it on presents the read‑only Health permission sheet and folds Health signals into your travel personality.
- **Home** — pick a country and optionally a city. Used for the furthest‑trip calculation, as the trip‑detection boundary (a photo within 50 km of home ends a trip), and to exclude everyday photos within 50 km of home from your travel personality.
- **Travel Calendar** — a month grid with a flag on every trip day; tap a day to open the trip, or share the month as a branded card.
- **Reindex photo library** — rebuilds travel history from scratch. Use it after changing the location or date of photos that were already scanned (a normal incremental scan keeps the original data because the asset id is unchanged), or to backfill altitude onto previously scanned photos.
- **Recaps** — archive of every year with travel; the current year also has a dedicated entry on the dashboard.

## Localization

Photrail ships in **English** and **Dutch (Flemish)**, using **String Catalogs** (`.xcstrings`). The app and the widget each have their own catalog (they're separate targets). iOS picks the language from the device, and users can override it per‑app in **Settings → Photrail → Language**.

Conventions:
- SwiftUI `Text("literal")` and `.navigationTitle("…")` localize automatically. Strings passed through reusable components use `LocalizedStringKey`; strings built in code use `String(localized:)`.
- **Counts** go through `LocalizedCounts` (`L.days`, `L.trips`, …) so plurals are grammatically correct in every language (catalog plural variations).
- **Country names and dates** come from the system (`Locale`/`DateFormatter`) — no manual translation needed. **City names** are data and stay as captured.
- **Shareable cards stay English by design** (built for an international audience): each card view forces `\.environment(\.locale, "en_US")` and uses English‑only helpers (`Trip.englishDisplayName`, `TravelCategory.englishTitle`, `Trip.englishDateRange`, `TravelTitle`/`TravelScore.tier`).

**Adding a language:** add it under **Project → Info → Localizations**, then open each `Localizable.xcstrings` in Xcode and fill the new column. Untranslated keys fall back to English automatically.

## Testing

`⌘U` runs the unit tests, including:

- **Travel personality** (`PhotrailTests/TravelPersonalityEngineTests.swift`): urban/nature/culture/transit classification, the home‑radius exclusion, percentage normalization, and confidence scaling.
- **Trip Insights** (`PhotrailTests/TravelInsightsEngineTests.swift`): elevation‑milestone selection, food‑equivalent math, persona thresholds, heart‑rate‑to‑photo window matching, workout grouping, the photo‑authorship filename heuristic, and the Health→personality direction vectors. The engine is pure, so these run without HealthKit entitlements or a device.

> Trip Insights requires the **HealthKit** capability (Signing & Capabilities) and a device or a simulator seeded with Health data; the on‑device UI can't be exercised in unit tests.

## License

GNU General Public License v3.0 — see [LICENSE](LICENSE).

---

<div align="center">

<img src=".github/assets/logo.svg" alt="Photrail" width="52" />

**Photrail** — Your travel history, automatically.

[photrail.berendvandenbussche.be](https://photrail.berendvandenbussche.be)

</div>
