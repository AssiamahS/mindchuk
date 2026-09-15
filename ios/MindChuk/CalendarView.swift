import SwiftUI
import SwiftData

struct CalendarView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @State private var day = Date.now
    @State private var editing: Note?

    private var reminders: [Note] {
        notes.filter { n in n.remindAt.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false }
            .sorted { ($0.remindAt ?? .distantPast) < ($1.remindAt ?? .distantPast) }
    }
    private var captured: [Note] {
        notes.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: day) && !$0.isReminder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    DatePicker("Day", selection: $day, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 8)
                    section("Reminders", reminders, empty: "No reminders on this day.")
                    section("Captured", captured, empty: "Nothing captured on this day.")
                }
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Today") { day = .now } }
            }
            .sheet(item: $editing) { NoteEditor(note: $0) }
        }
    }

    private func section(_ title: String, _ items: [Note], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(Theme.dim)
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(Theme.muted)
            }
            ForEach(items) { n in
                NoteCard(note: n, compact: true)
                    .onTapGesture { editing = n }
                    .contextMenu { NoteMenu(note: n, edit: { editing = n }) }
            }
        }
        .padding(.horizontal, 16)
    }
}
