import SwiftUI

/// The page of a planned trip: its countries and dates, the countdown (or the day of the trip
/// while it's underway), and the flights with a map of the route. "Edit" opens the plan
/// editor; flights have their own editor.
///
/// Looks the plan up by id, so edits show straight away, and closes itself if it's deleted.
struct PlannedTripDetailView: View {
    let planID: String

    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var showFlightsEditor = false
    /// The country whose info page is open.
    @State private var infoStay: PlannedTrip.Stay?

    private var plan: PlannedTrip? { appVM.plannedTrips.first { $0.id == planID } }

    var body: some View {
        Group {
            if let plan {
                content(plan)
            } else {
                Color.clear
            }
        }
        .onChange(of: plan == nil) { _, gone in if gone { dismiss() } }
    }

    private func content(_ plan: PlannedTrip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(plan)
                countriesSection(plan)
                flightsSection(plan)
                if plan.isUnderway(), let trip = plan.matchingTrip(in: appVM.stats.trips) {
                    NavigationLink { TripDetailView(trip: trip) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled").foregroundStyle(.tint)
                            Text("See your photos").foregroundStyle(.primary)
                            Spacer()
                            Text("\(trip.photoCount) photos").font(.subheadline).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(AppCard.padding)
                        .card()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(plan.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditor = true }
            }
        }
        .sheet(isPresented: $showEditor) { PlannedTripEditorView(existing: plan) }
        .sheet(item: $infoStay) { stay in
            if let tips = countryTips(stay) {
                CountryInfoView(tips: tips)
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showFlightsEditor) {
            FlightsEditorSheet(flights: plan.flights,
                               segments: FlightSuggestions.segments(for: plan)) { flights in
                var updated = plan
                updated.flights = flights
                appVM.savePlannedTrip(updated)
            }
        }
    }

    // MARK: - Header

    private func header(_ plan: PlannedTrip) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(red: 0.20, green: 0.18, blue: 0.45),
                                    Color(red: 0.33, green: 0.20, blue: 0.52)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(plan.flags)
                .font(.system(size: plan.countryCodes.count > 1 ? 60 : 84))
                .opacity(0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                if plan.isUnderway() { LiveTripPill().padding(.bottom, 4) }
                Text(plan.dateRangeText.uppercased())
                    .font(.system(size: 12, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.85))
                Text(verbatim: "\(plan.flags) \(plan.displayName)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2).minimumScaleFactor(0.6)
                Text(statusText(plan))
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .frame(height: 240)
        .clipped()
    }

    /// "in 21 days", "Tomorrow", or "Day 3 of 14 · Brazil" while underway.
    private func statusText(_ plan: PlannedTrip) -> String {
        guard let day = plan.dayNumber() else { return plan.countdownText() }
        var text = String(localized: "Day \(day) of \(plan.length())")
        if plan.countryCodes.count > 1, let stay = plan.stay(on: Date()) {
            text += " · \(stay.localizedCountry)"
        }
        return text
    }

    // MARK: - Countries

    private func countriesSection(_ plan: PlannedTrip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: plan.stays.count > 1 ? "Countries" : "Destination")
                .padding(.horizontal, 20)
            VStack(spacing: 0) {
                ForEach(plan.stays) { stay in
                    HStack(spacing: 12) {
                        Text(stay.flag).font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stay.localizedCountry).font(.subheadline.weight(.semibold))
                            Text(Self.range(stay.startDate, stay.endDate))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(L.days(stay.length())).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if CountryInfoDirectory.info(for: stay.countryCode) != nil {
                            Button { infoStay = stay } label: {
                                Image(systemName: "info.circle").font(.title3)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text("About \(stay.localizedCountry)"))
                        }
                    }
                    .padding(.vertical, 10)
                    if stay.id != plan.stays.last?.id { Divider().padding(.leading, 44) }
                }
            }
            .padding(.horizontal, AppCard.padding)
            .card()
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Country info

    /// The tips for one country of the plan, for the dates the user is there.
    private func countryTips(_ stay: PlannedTrip.Stay) -> CountryTips? {
        CountryTips.make(destination: stay.countryCode, home: appVM.homeCountryCode,
                         on: stay.startDate, homeZone: homeZone)
    }

    /// The time at home: the home country's zone nearest the home location, else the device's.
    private var homeZone: TimeZone {
        guard let code = appVM.homeCountryCode else { return .current }
        if let home = appVM.homeCoordinate,
           let zone = TripTimeZone.zone(countryCode: code, latitude: home.latitude, longitude: home.longitude) {
            return zone
        }
        return TripTimeZone.zones(countryCode: code).first ?? .current
    }

    // MARK: - Flights

    private func flightsSection(_ plan: PlannedTrip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Flights", systemImage: "airplane",
                          action: plan.flights.isEmpty ? nil : { showFlightsEditor = true },
                          actionLabel: "Edit")
                .padding(.horizontal, 20)

            if plan.flights.isEmpty {
                Button { showFlightsEditor = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "airplane.departure").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add flights").foregroundStyle(.primary)
                            Text("Getting there, between countries and coming home.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill").foregroundStyle(.tint)
                    }
                    .padding(AppCard.padding)
                    .card()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                FlightRouteMap(flights: plan.sortedFlights)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 20)
                let groups = FlightSuggestions.grouped(plan.flights)
                flightGroup("Getting there", groups.outbound)
                flightGroup("During the trip", groups.during)
                flightGroup("Coming home", groups.home)
            }
        }
    }

    /// One group of flights (worked out from the flights, so plans saved before the groups
    /// existed show them too) as a small header and a card; nothing when empty.
    @ViewBuilder
    private func flightGroup(_ title: LocalizedStringKey, _ flights: [PlannedTrip.Flight]) -> some View {
        if !flights.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 20 + AppCard.padding)
                    .padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(flights) { flight in
                        FlightLegLabel(flight: flight)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        if flight.id != flights.last?.id { Divider() }
                    }
                }
                .padding(.horizontal, AppCard.padding)
                .card()
                .padding(.horizontal, 20)
            }
        }
    }

    private static func range(_ start: Date, _ end: Date) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: start, to: end)
    }
}
