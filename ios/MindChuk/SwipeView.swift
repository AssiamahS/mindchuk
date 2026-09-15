import SwiftUI
import SwiftData

/// Triage deck: one card at a time. Left archives, right keeps (comes back around), up finishes into a tag.
struct SwipeView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @AppStorage("swipeFinishTag") private var finishTag = ""
    @AppStorage("swipeLeftDeletes") private var leftDeletes = false
    @State private var skipped: Set<UUID> = []
    @State private var offset: CGSize = .zero
    @State private var lastAction: (Note, String)?
    @State private var showSettings = false

    private var deck: [Note] {
        let live = notes.filter { !$0.isArchived && !$0.isDone }
        let fresh = live.filter { !skipped.contains($0.id) }
        return fresh.isEmpty ? live : fresh   // loops forever: skipped cards come back around
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                if let top = deck.first {
                    ZStack {
                        if deck.count > 1 {
                            NoteCard(note: deck[1]).scaleEffect(0.95).offset(y: 12).opacity(0.6)
                        }
                        NoteCard(note: top)
                            .offset(offset)
                            .rotationEffect(.degrees(Double(offset.width / 20)))
                            .overlay(alignment: .top) { hint }
                            .gesture(
                                DragGesture()
                                    .onChanged { offset = $0.translation }
                                    .onEnded { g in
                                        if g.translation.width < -110 { left(top) }
                                        else if g.translation.width > 110 { right(top) }
                                        else if g.translation.height < -110 { up(top) }
                                        withAnimation(.spring) { offset = .zero }
                                    }
                            )
                            .animation(.interactiveSpring, value: offset)
                    }
                    .padding(.horizontal, 20)
                    HStack(spacing: 28) {
                        action(leftDeletes ? "trash" : "archivebox", leftDeletes ? "Delete" : "Archive", Theme.danger) { left(top) }
                        action("arrow.up.circle", finishTag.isEmpty ? "Finish" : "#\(finishTag)", Theme.accent) { up(top) }
                        action("arrow.uturn.right", "Keep", .white) { right(top) }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 44)).foregroundStyle(Theme.accent)
                        Text("All caught up").font(.headline)
                        Text("New notes land here for a quick sort.").font(.subheadline).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                if let (n, what) = lastAction {
                    Button("Undo \(what)") { undo(n, what) }.font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                }
                Text("\(deck.count) in the deck · loops forever").font(.caption2).foregroundStyle(Theme.dim).padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Swipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showSettings) { swipeSettings }
        }
    }

    @ViewBuilder private var hint: some View {
        if offset.width < -60 {
            Text(leftDeletes ? "DELETE" : "ARCHIVE").font(.caption.weight(.black)).padding(6)
                .background(Theme.danger, in: Capsule()).foregroundStyle(.white).offset(y: -14)
        } else if offset.width > 60 {
            Text("KEEP").font(.caption.weight(.black)).padding(6)
                .background(.white, in: Capsule()).foregroundStyle(.black).offset(y: -14)
        } else if offset.height < -60 {
            Text(finishTag.isEmpty ? "FINISH" : "#\(finishTag.uppercased())").font(.caption.weight(.black)).padding(6)
                .background(Theme.accent, in: Capsule()).foregroundStyle(.black).offset(y: -14)
        }
    }

    private func action(_ icon: String, _ label: String, _ color: Color, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2).frame(width: 60, height: 60)
                    .background(Theme.card, in: Circle()).overlay(Circle().stroke(color.opacity(0.6)))
                Text(label).font(.caption2.weight(.semibold))
            }.foregroundStyle(color)
        }
    }

    private func left(_ n: Note) {
        // Archive first so "Undo" can bring it back; a delete becomes real after the undo window closes.
        n.isArchived = true
        lastAction = (n, leftDeletes ? "delete" : "archive")
        try? ctx.save()
        guard leftDeletes else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            if n.isArchived, lastAction?.0.id == n.id {
                Store.delete(n, in: ctx)
                lastAction = nil
            }
        }
    }
    private func right(_ n: Note) { skipped.insert(n.id); lastAction = (n, "keep") }
    private func up(_ n: Note) {
        if let t = tags.first(where: { $0.name == finishTag }), !n.tags.contains(where: { $0.name == t.name }) { n.tags.append(t) }
        n.isDone = true
        Reminders.cancel(n)
        try? ctx.save()
        lastAction = (n, "finish")
    }
    private func undo(_ n: Note, _ what: String) {
        switch what {
        case "archive", "delete": n.isArchived = false
        case "keep": skipped.remove(n.id)
        case "finish": n.isDone = false
        default: break
        }
        try? ctx.save(); lastAction = nil
    }

    private var swipeSettings: some View {
        NavigationStack {
            Form {
                Section("Swipe up finishes into") {
                    Picker("Tag", selection: $finishTag) {
                        Text("Just mark done").tag("")
                        ForEach(tags) { Text("#\($0.name)").tag($0.name) }
                    }
                    if tags.isEmpty { Text("No tags yet, make one first.").font(.caption).foregroundStyle(Theme.muted) }
                }
                Section {
                    Toggle("Swipe left deletes", isOn: $leftDeletes)
                } footer: {
                    Text("Set to Delete, swiping that way removes the note for good. You can undo the last one for a few seconds, but nothing before it.")
                }
            }
            .scrollContentBackground(.hidden).background(Theme.bg)
            .navigationTitle("Swipe settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSettings = false } } }
        }
    }
}
