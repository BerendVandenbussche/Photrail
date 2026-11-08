import SwiftUI

/// Plan a trip, or edit or delete a plan: an optional name and one or more countries, each
/// with its own dates. Flights are edited from the plan's page. Shown from `MainTabView` via
/// `AppViewModel.planEditor`.
struct PlannedTripEditorView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    let existing: PlannedTrip?

    /// A stay being edited; the country is nil until one is picked.
    private struct DraftStay: Identifiable {
        var id = UUID().uuidString
        var countryCode: String?
        var startDate: Date
        var endDate: Date
    }

    @State private var name: String
    @State private var stays: [DraftStay]
    @State private var pickingCountryFor: String?
    @State private var showDeleteConfirm = false

    init(existing: PlannedTrip?, countryCode: String? = nil) {
        self.existing = existing
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: 14, to: calendar.startOfDay(for: Date())) ?? Date()
        _name = State(initialValue: existing?.name ?? "")
        _stays = State(initialValue: existing?.stays.map {
            DraftStay(id: $0.id, countryCode: $0.countryCode, startDate: $0.startDate, endDate: $0.endDate)
        } ?? [DraftStay(countryCode: countryCode, startDate: start,
                        endDate: calendar.date(byAdding: .day, value: 6, to: start) ?? start)])
    }

    private var canSave: Bool { !stays.isEmpty && stays.allSatisfy { $0.countryCode != nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (optional)", text: $name)
                }

                ForEach($stays) { $stay in
                    Section {
                        Button { pickingCountryFor = stay.id } label: {
                            HStack(spacing: 12) {
                                if let code = stay.countryCode {
                                    Text(CountryCatalog.flag(for: code)).font(.system(size: 26))
                                    Text(CountryCatalog.name(for: code)).foregroundStyle(.primary)
                                } else {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.tint)
                                    Text("Choose a country").foregroundStyle(.tint)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        DatePicker("From", selection: $stay.startDate, displayedComponents: .date)
                            .onChange(of: stay.startDate) { _, start in
                                if stay.endDate < start { stay.endDate = start }
                            }
                        DatePicker("To", selection: $stay.endDate, in: stay.startDate..., displayedComponents: .date)
                        if stays.count > 1 {
                            Button(role: .destructive) {
                                stays.removeAll { $0.id == stay.id }
                            } label: {
                                Label("Remove country", systemImage: "minus.circle")
                            }
                        }
                    } header: {
                        if stay.id == stays.first?.id { Text("Countries") }
                    }
                }

                Section {
                    Button(action: addStay) {
                        Label("Add country", systemImage: "plus.circle.fill")
                    }
                } footer: {
                    Text("For a trip through several countries, add each one with its own dates. Flights are added on the trip's page.")
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete plan", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(existing == nil ? Text("Plan a Trip") : Text("Edit Plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .sheet(item: Binding(get: { pickingCountryFor.map(PickerTarget.init) },
                                 set: { pickingCountryFor = $0?.id })) { target in
                CountryPickerSheet(excluding: [], onPick: { option in
                    if let i = stays.firstIndex(where: { $0.id == target.id }) {
                        stays[i].countryCode = option.code
                    }
                }, title: "Destination")
            }
            .confirmationDialog("Delete this plan?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete plan", role: .destructive) {
                    if let existing { appVM.removePlannedTrip(id: existing.id) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its reminders are cancelled too.")
            }
        }
    }

    private struct PickerTarget: Identifiable { let id: String }

    /// A new country starts on the day the last one ends (the day you travel on).
    private func addStay() {
        let calendar = Calendar.current
        let start = stays.map(\.endDate).max() ?? calendar.startOfDay(for: Date())
        stays.append(DraftStay(countryCode: nil, startDate: start,
                               endDate: calendar.date(byAdding: .day, value: 4, to: start) ?? start))
        pickingCountryFor = stays.last?.id
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finished = stays.compactMap { draft in
            draft.countryCode.map {
                PlannedTrip.Stay(id: draft.id, countryCode: $0, startDate: draft.startDate, endDate: draft.endDate)
            }
        }
        let plan = PlannedTrip(id: existing?.id ?? UUID().uuidString,
                               name: trimmed.isEmpty ? nil : trimmed,
                               stays: finished,
                               flights: existing?.flights ?? [])
        appVM.savePlannedTrip(plan)
        // A new plan opens on its own page next, where flights are added.
        if existing == nil { appVM.planToShowAfterEditor = plan.id }
        dismiss()
    }
}
