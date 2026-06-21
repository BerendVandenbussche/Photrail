# Photrail

Photrail automatically turns your photo library into a beautiful travel map. It reads the GPS metadata already embedded in your photos — no manual tagging, no accounts, no cloud.

---

## Features

- **World map** — Interactive map with a pin for every country you've visited
- **Travel statistics** — Countries visited, cities explored, percentage of the world covered, most photographed country
- **Monthly activity timeline** — Bar chart showing your photo activity over time
- **Country detail view** — Photo grid, city breakdown, and visit history per country
- **Shareable cards** — Export beautiful stat cards in four themes (Midnight, Dawn, Forest, Ocean) via the native share sheet
- **Smart caching** — Uses the PhotoKit change token to skip rescanning when your library hasn't changed

## Privacy

Everything runs entirely on-device.

- No backend, no accounts, no analytics
- Photos never leave your phone
- Only EXIF GPS metadata is read — actual image data is only loaded when displaying thumbnails
- Photo library access can be revoked at any time in Settings

## Requirements

- iOS 18+
- Xcode 16+

## Architecture

Clean MVVM with Swift Concurrency throughout.

```
Photrail/
├── App/
│   └── RootView.swift              State machine: onboarding → scanning → dashboard
├── Models/
│   ├── GeoPhoto.swift              Single geotagged photo (Codable, Sendable)
│   ├── CountryStat.swift           Aggregated country + city statistics
│   └── TravelStats.swift           Full stats snapshot + mock data for previews
├── Services/
│   ├── PhotoScanService.swift      Scans PHAsset library in batches of 200
│   ├── GeocodingService.swift      Reverse geocoding with rate limiting + cache
│   ├── CacheService.swift          JSON persistence, keyed on PHPhotoLibrary change token
│   └── StatisticsEngine.swift      Pure [GeoPhoto] → TravelStats transformation
├── ViewModels/
│   ├── AppViewModel.swift          @Observable root state machine
│   ├── DashboardViewModel.swift    Derived display properties
│   └── CountryDetailViewModel.swift PHCachingImageManager for photo grids
├── Views/
│   ├── Onboarding/                 3-page onboarding + permission denied screen
│   ├── Dashboard/                  Map, stats grid, countries carousel, timeline
│   ├── CountryDetail/              City list + lazy 3-column photo grid
│   └── ShareCard/                  4 card types × 4 themes, exported via ImageRenderer
└── Components/
    ├── StatCard.swift              Reusable metric card
    ├── SectionHeader.swift         Consistent section labels
    ├── PhotoThumbnail.swift        Async PHAsset thumbnail loader
    └── ScanProgressView.swift      Animated progress ring
```

Key technical decisions:

| Decision | Reason |
|---|---|
| `actor` for all services | Prevents data races when processing large libraries off the main thread |
| PHPhotoLibrary change token | Avoids rescanning unchanged libraries on every app launch |
| CLGeocoder rate limiting (1 req/s) | Apple enforces a geocoding rate limit; exceeding it silently returns errors |
| Rounded coordinate cache key | Photos taken in the same area share a geocoding result, reducing API calls by ~80% |
| `PBXFileSystemSynchronizedRootGroup` | Xcode 16 folder sync — new Swift files are picked up automatically without editing the pbxproj |

## Getting started

1. Clone the repo
2. Open `Photrail.xcodeproj`
3. Select your development team in **Signing & Capabilities**
4. Run on a physical device (photo library access is not available in the Simulator)

## License

MIT
