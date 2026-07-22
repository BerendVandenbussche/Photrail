import SwiftUI
import MapKit

/// A single Workout Chapter: the workout's stats, its GPS route (if any), and the photos
/// taken during that workout grouped as a sub-album.
struct WorkoutChapterView: View {
    let chapter: WorkoutChapter
    @Environment(\.dismiss) private var dismiss

    private var routeCoordinates: [CLLocationCoordinate2D] {
        chapter.route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    statChips

                    if chapter.hasRoute {
                        Map {
                            MapPolyline(coordinates: routeCoordinates)
                                .stroke(Color.accentColor, lineWidth: 4)
                        }
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 20)
                    }

                    if !chapter.photoIDs.isEmpty {
                        PhotoGridSection(title: "Photos from this workout",
                                         photoIDs: chapter.photoIDs, limit: 60)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(activityTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(chapter.emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(activityTitle).font(.title3.weight(.bold))
                Text(dateLabel).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }

    private var statChips: some View {
        FlowLayout(spacing: 10, rowSpacing: 10) {
            chip("clock", chapter.durationText, "Duration")
            if let d = chapter.distanceMeters, d > 0 {
                chip("figure.walk", "\(String(format: "%.1f", d / 1000)) km", "Distance")
            }
            if let e = chapter.activeEnergyKcal, e > 0 {
                chip("flame", "\(Int(e)) kcal", "Energy")
            }
            chip("photo.stack", "\(chapter.photoIDs.count)", "Photos")
        }
        .padding(.horizontal, 20)
    }

    private func chip(_ icon: String, _ value: String, _ label: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold))
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .card(cornerRadius: AppCard.chipRadius)
    }

    private var activityTitle: LocalizedStringKey {
        switch chapter.activityKey {
        case "running":      return "Run"
        case "walking":      return "Walk"
        case "cycling":      return "Ride"
        case "hiking":       return "Hike"
        case "swimming":     return "Swim"
        case "yoga":         return "Yoga"
        case "climbing":     return "Climb"
        case "snowboarding": return "Snowboard"
        case "skiing":       return "Ski"
        case "snowSports":   return "Snow Sports"
        case "skating":      return "Skating"
        default:             return "Workout"
        }
    }

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy · HH:mm"
        return fmt.string(from: chapter.start)
    }
}
