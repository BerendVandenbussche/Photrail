# App Store submission notes

Draft copy and the exact answers to give in App Store Connect. Tweak wording to taste.

## Listing

**Name:** Photrail

**Subtitle (30 chars max):** Your travel map, automatically

**Promotional text (170 chars):**
Turn your camera roll into a travel map. Photrail reads the location already in your photos to show every country, trip and wonder you've visited — 100% on your device.

**Description:**
Photrail turns your photo library into a beautiful map of everywhere you've been — automatically. It reads the location data already saved in your photos, so there's nothing to tag and no account to create. Everything happens on your device.

WHAT YOU GET
• World map — a pin for every country you've visited
• Places — browse your countries, continents, world wonders and trips
• Trips — every journey detected automatically, with a map, itinerary and photos
• On This Day — rediscover photos from this date in past years
• Travel personality — see your style (Urban, Coastal, Mountain, Nature, Culture, Adventure…), measured on‑device
• Year in Travel — a beautiful, shareable recap of your year
• Home‑screen widgets — your travel stats and world wonders at a glance

PRIVATE BY DESIGN
• No account, no ads, no analytics, no tracking
• Country, trip, wonder and personality detection all run on your device
• Your photos never leave your phone
• Read‑only access to your photo library

Missing a country because the photos are gone? Add it by hand to keep your map accurate.

**Keywords (100 chars):**
travel,map,countries,trips,passport,visited,photo,recap,wonders,journey,stats,been,world,vacation

**Support URL / Marketing URL:**
photrail.berendvandenbussche.be

**Category:** Travel (secondary: Photo & Video)

**Age rating:** 4+

## App Privacy answers (App Store Connect → App Privacy)

- **Data collection:** "No, we do not collect data from this app." → results in **Data Not Collected**.
- This matches the bundled `PrivacyInfo.xcprivacy` (no tracking, no collected data types).
- Photo access is read‑only and used only on‑device; nothing is uploaded.

## Export compliance

- Uses only standard system HTTPS (Apple `CLGeocoder`) → **exempt**.
- `ITSAppUsesNonExemptEncryption = false` is set in Info.plist, so no per‑upload prompt.

## Review notes (App Review "Notes" field)

Photrail is fully on‑device. To see it populated during review, sign in on a device (or simulator) whose photo library contains geotagged photos from a few different countries. On first launch, grant photo access; the map and stats build automatically after a short scan. No account or login is required.
