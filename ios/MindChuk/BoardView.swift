import SwiftUI
import SwiftData

/// Kanban: pick 2–5 tags, each becomes a column. Cards move between columns from their menu.
struct BoardView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @AppStorage("boardColumns") private var columnsRaw = ""
    @State private var setup = false
    @State private var editing: Note?

    private var columns: [Tag] {
        let names = columnsRaw.split(separator: ",").map(String.init)
        return names.compactMap { n in tags.first { $0.name == n } }
    }

    var body: some View {
        NavigationStack {
            Group {
                if columns.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.split.3x1").font(.system(size: 44)).foregroundStyle(Theme.dim)
                        Text("Set up board view").font(.headline)
                        Text(tags.isEmpty ? "Create a tag first, then pick columns." : "Choose 2–5 tags to become columns.")
                            .font(.subheadline).foregroundStyle(Theme.muted)
                        Button("Set up columns") { setup = true }.buttonStyle(.borderedProminent).disabled(tags.isEmpty)
                    }
                } else {
                    ScrollView(.horizontal) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(columns) { col in column(col) }
                            archiveColumn
                        }
                        .padding(16)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { setup = true } label: { Image(systemName: "slider.horizontal.3") }.disabled(tags.isEmpty)
                }
            }
            .sheet(isPresented: $setup) { BoardSetup(columnsRaw: $columnsRaw) }
            .sheet(item: $editing) { NoteEditor(note: $0) }
        }
    }

    private func column(_ tag: Tag) -> some View {
        let items = notes.filter { !$0.isArchived && $0.tags.contains { $0.name == tag.name } }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(tag.color).frame(width: 8, height: 8)
                Text("#\(tag.name)").font(.subheadline.weight(.bold))
                Spacer()
                Text("\(items.count)").font(.caption).foregroundStyle(Theme.dim)
            }
            .padding(.horizontal, 4)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { n in
                        NoteCard(note: n, compact: true)
                            .onTapGesture { editing = n }
                            .contextMenu { NoteMenu(note: n, edit: { editing = n }) }
                    }
                    if items.isEmpty {
                        Text("Nothing filed here yet.").font(.caption).foregroundStyle(Theme.dim).padding()
                    }
                }
            }
        }
        .frame(width: 300)
        .containerRelativeFrame(.vertical)
    }

    private var archiveColumn: some View {
        let items = notes.filter(\.isArchived)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox").font(.caption)
                Text("Archive").font(.subheadline.weight(.bold))
                Spacer()
                Text("\(items.count)").font(.caption).foregroundStyle(Theme.dim)
            }.padding(.horizontal, 4)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(items) { n in
                        NoteCard(note: n, compact: true).contextMenu { NoteMenu(note: n, edit: { editing = n }) }
                    }
                    if items.isEmpty {
                        Text("Use “Archive” on a card's menu to tuck it here.").font(.caption).foregroundStyle(Theme.dim).padding()
                    }
                }
            }
        }
        .frame(width: 300)
        .containerRelativeFrame(.vertical)
    }
}

struct BoardSetup: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Binding var columnsRaw: String
    @State private var picked: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(tags) { t in
                        Button {
                            if let i = picked.firstIndex(of: t.name) { picked.remove(at: i) }
                            else if picked.count < 5 { picked.append(t.name) }
                        } label: {
                            HStack {
                                Circle().fill(t.color).frame(width: 10, height: 10)
                                Text("#\(t.name)")
                                Spacer()
                                if let i = picked.firstIndex(of: t.name) {
                                    Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                                }
                            }
                        }.foregroundStyle(.primary)
                    }
                } header: { Text("Choose 2–5 tags to become columns") }
            }
            .scrollContentBackground(.hidden).background(Theme.bg)
            .navigationTitle("Set up columns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save columns") { columnsRaw = picked.joined(separator: ","); dismiss() }
                        .disabled(picked.count < 2).fontWeight(.bold)
                }
            }
            .onAppear { picked = columnsRaw.split(separator: ",").map(String.init) }
        }
    }
}
