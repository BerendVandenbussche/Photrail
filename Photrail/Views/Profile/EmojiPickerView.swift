import SwiftUI

/// A small curated grid of travel emojis the user can pick as their avatar.
struct EmojiPickerView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    private let emojis = [
        "🧭", "🌍", "🌎", "🌏", "✈️", "🗺", "📸", "🎒",
        "🏔", "🏝", "🏕", "🏞", "🌋", "🏜", "🏖", "⛰️",
        "🚗", "🚂", "🛶", "🛩", "🚙", "⛵️", "🧗", "🏄",
        "🐧", "🦒", "🐳", "🌅", "🌃", "🗽", "🏰", "🛕"
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            appVM.profileEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 34))
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle().fill(appVM.profileEmoji == emoji
                                                  ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                )
                                .overlay(
                                    Circle().strokeBorder(appVM.profileEmoji == emoji ? Color.accentColor : .clear,
                                                          lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Choose an emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
