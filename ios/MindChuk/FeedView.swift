import SwiftUI
import SwiftData
import PhotosUI

struct FeedView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var search = ""
    @State private var selectedTag: String?
    @State private var showArchived = false
    @State private var compact = false
    @State private var oldestFirst = false
    @State private var editing: Note?

    private var filtered: [Note] {
        var list = notes.filter { $0.isArchived == showArchived }
        if let t = selectedTag {
            list = list.filter { $0.tags.contains { $0.name == t } }
        }
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter { $0.text.lowercased().contains(q) || $0.tags.contains { $0.name.contains(q) } }
        }
        if oldestFirst { list.reverse() }
        return list
    }

    private var grouped: [(String, [Note])] {
        let cal = Calendar.current
        let df = DateFormatter(); df.dateFormat = "EEEE, MMM d"
        var out: [(String, [Note])] = []
        for n in filtered {
            let label = cal.isDateInToday(n.createdAt) ? "Today"
                : cal.isDateInYesterday(n.createdAt) ? "Yesterday" : df.string(from: n.createdAt)
            if let i = out.firstIndex(where: { $0.0 == label }) { out[i].1.append(n) } else { out.append((label, [n])) }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !tags.isEmpty { tagBar }
                feed
                Composer()
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle(selectedTag.map { "#\($0)" } ?? "MindChuk")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search by text or tag…")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Compact view", isOn: $compact)
                        Toggle("Sort: oldest first", isOn: $oldestFirst)
                        Toggle("Show archived", isOn: $showArchived)
                        NavigationLink { TagsView() } label: { Label("Manage tags", systemImage: "number") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $editing) { NoteEditor(note: $0) }
        }
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: selectedTag == nil, color: .white) { selectedTag = nil }
                ForEach(tags) { t in
                    chip("#\(t.name)", selected: selectedTag == t.name, color: t.color) {
                        selectedTag = selectedTag == t.name ? nil : t.name
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
    }

    private func chip(_ label: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? color.opacity(0.18) : Theme.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? color : Theme.cardBorder, lineWidth: 1))
                .foregroundStyle(selected ? color : Theme.muted)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var feed: some View {
        if filtered.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 44)).foregroundStyle(Theme.dim)
                Text(search.isEmpty ? "Nothing here yet." : "No results found.")
                    .font(.headline)
                if search.isEmpty {
                    Text("Send yourself anything below. Ideas, notes, links, lists. Add #tags to file it. Start with “remind me” to get pinged.")
                        .font(.subheadline).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10, pinnedViews: []) {
                    ForEach(grouped, id: \.0) { label, group in
                        Text(label.uppercased())
                            .font(.caption2.weight(.bold)).foregroundStyle(Theme.dim)
                            .padding(.top, 8).padding(.horizontal, 4)
                        ForEach(group) { note in
                            NoteCard(note: note, compact: compact)
                                .onTapGesture { editing = note }
                                .contextMenu { NoteMenu(note: note, edit: { editing = note }) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Composer ("What's on your mind?")

struct Composer: View {
    @Environment(\.modelContext) private var ctx
    @State private var text = ""
    @State private var photos: [PhotosPickerItem] = []
    @State private var images: [Data] = []
    @FocusState private var focused: Bool

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty || !images.isEmpty }

    var body: some View {
        VStack(spacing: 6) {
            if !images.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(Array(images.enumerated()), id: \.offset) { i, d in
                            if let ui = UIImage(data: d) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .topTrailing) {
                                        Button { images.remove(at: i) } label: {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black)
                                        }.offset(x: 6, y: -6)
                                    }
                            }
                        }
                    }.padding(.horizontal, 16)
                }
            }
            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $photos, maxSelectionCount: 4, matching: .images) {
                    Image(systemName: "paperclip").font(.title3).foregroundStyle(Theme.muted)
                        .frame(width: 36, height: 36)
                }
                .onChange(of: photos) { _, items in
                    Task {
                        var out: [Data] = []
                        for item in items {
                            if let d = try? await item.loadTransferable(type: Data.self),
                               let ui = UIImage(data: d), let jpg = ui.jpegData(compressionQuality: 0.7) {
                                out.append(jpg)
                            }
                        }
                        images.append(contentsOf: out)
                        photos = []
                    }
                }
                TextField("What's on your mind?", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.field, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.cardBorder))
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.headline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(canSend ? Theme.accent : Theme.card, in: Circle())
                        .foregroundStyle(canSend ? .black : Theme.dim)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 8)
        }
        .background(Theme.bg)
    }

    private func send() {
        Store.addNote(text, images: images, in: ctx)
        text = ""; images = []
    }
}

// MARK: - Card

struct NoteCard: View {
    @Environment(\.modelContext) private var ctx
    let note: Note
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if note.isReminder, let d = note.remindAt {
                HStack(spacing: 6) {
                    Image(systemName: note.isDone ? "checkmark.circle.fill" : "bell.fill")
                    Text(d.formatted(date: .abbreviated, time: .shortened))
                    if d < .now && !note.isDone { Text("· past").foregroundStyle(Theme.dim) }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(note.isDone ? Theme.dim : Theme.accent)
            }
            Text(highlighted(note.text))
                .font(compact ? .subheadline : .body)
                .lineLimit(compact ? 2 : nil)
                .strikethrough(note.isDone, color: Theme.dim)
                .foregroundStyle(note.isDone ? Theme.muted : .primary)
            if !compact, !note.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(note.images.enumerated()), id: \.offset) { _, d in
                            if let ui = UIImage(data: d) {
                                Image(uiImage: ui).resizable().scaledToFill()
                                    .frame(width: 140, height: 140).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            if !compact, let url = note.link {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "link").font(.caption)
                        Text(url.host() ?? url.absoluteString).font(.caption.weight(.medium)).lineLimit(1)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption2)
                    }
                    .padding(10)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder))
                    .foregroundStyle(Theme.muted)
                }
            }
            HStack(spacing: 6) {
                ForEach(note.tags) { t in
                    Text("#\(t.name)").font(.caption2.weight(.bold)).foregroundStyle(t.color)
                }
                Spacer()
                Text(note.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(Theme.dim)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.cardBorder))
        .opacity(note.isArchived ? 0.6 : 1)
    }

    private func highlighted(_ text: String) -> AttributedString {
        var a = AttributedString(text)
        for tag in Parser.hashtags(in: text) {
            if let r = a.range(of: "#\(tag)", options: .caseInsensitive) {
                a[r].foregroundColor = note.tags.first { $0.name == tag }?.color ?? Theme.accent
                a[r].font = .body.weight(.semibold)
            }
        }
        return a
    }
}

struct NoteMenu: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Tag.name) private var tags: [Tag]
    let note: Note
    var edit: () -> Void

    var body: some View {
        Button { edit() } label: { Label("Edit", systemImage: "pencil") }
        if note.isReminder {
            Button {
                note.isDone.toggle()
                if note.isDone { Reminders.cancel(note) } else { Reminders.schedule(note) }
                try? ctx.save()
            } label: { Label(note.isDone ? "Mark not done" : "Mark done", systemImage: "checkmark.circle") }
        }
        Menu("Move to tag") {
            ForEach(tags) { t in
                Button {
                    if note.tags.contains(where: { $0.name == t.name }) {
                        note.tags.removeAll { $0.name == t.name }
                    } else { note.tags.append(t) }
                    try? ctx.save()
                } label: {
                    Label("#\(t.name)", systemImage: note.tags.contains(where: { $0.name == t.name }) ? "checkmark" : "number")
                }
            }
        }
        Button {
            note.isArchived.toggle(); try? ctx.save()
        } label: { Label(note.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") }
        ShareLink(item: note.text) { Label("Share", systemImage: "square.and.arrow.up") }
        Button(role: .destructive) { Store.delete(note, in: ctx) } label: { Label("Delete", systemImage: "trash") }
    }
}

// MARK: - Editor

struct NoteEditor: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let note: Note
    @State private var text = ""
    @State private var hasReminder = false
    @State private var remindAt = Date.now.addingTimeInterval(3600)
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Note", text: $text, axis: .vertical).lineLimit(3...12)
                } footer: {
                    Text("Use #tags to file it. Trigger words file it too.")
                }
                Section("Reminder") {
                    Toggle("Remind me", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("When", selection: $remindAt, in: Date.now...)
                    }
                }
                Section {
                    Button("Delete note", role: .destructive) { confirmDelete = true }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.fontWeight(.bold) }
            }
            .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { Store.delete(note, in: ctx); dismiss() }
            } message: { Text("This cannot be undone.") }
            .onAppear {
                text = note.text
                hasReminder = note.remindAt != nil
                remindAt = note.remindAt ?? Date.now.addingTimeInterval(3600)
            }
        }
    }

    private func save() {
        Store.update(note, text: text, in: ctx)
        Store.setReminder(note, at: hasReminder ? remindAt : nil, in: ctx)
        dismiss()
    }
}
