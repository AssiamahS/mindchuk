import SwiftUI
import SwiftData

struct TagsView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var newName = ""
    @State private var newTriggers = ""
    @State private var parent: String = ""
    @State private var error: String?

    var body: some View {
        List {
            Section {
                TextField("Name your tag (e.g. groceries)", text: $newName)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Trigger words, comma separated (optional)", text: $newTriggers)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if !tags.isEmpty {
                    Picker("Lives inside", selection: $parent) {
                        Text("Stands on its own").tag("")
                        ForEach(tags) { Text("#\($0.name)").tag($0.name) }
                    }
                }
                if let error { Text(error).font(.caption).foregroundStyle(Theme.danger) }
                Button("Add tag") { add() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } header: { Text("New tag") } footer: {
                Text("Write #name in any note and it files itself here. Trigger words are extra words that do the same.")
            }
            Section("Your tags") {
                if tags.isEmpty {
                    Text("No tags yet. Add your first one above.").foregroundStyle(Theme.muted)
                }
                ForEach(tags) { t in
                    NavigationLink { TagDetail(tag: t) } label: {
                        HStack {
                            Circle().fill(t.color).frame(width: 10, height: 10)
                            Text("#\(t.name)").fontWeight(.semibold)
                            if let p = t.parentName { Text("in #\(p)").font(.caption).foregroundStyle(Theme.dim) }
                            Spacer()
                            Text("\(t.notes.count)").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .onDelete { idx in idx.map { tags[$0] }.forEach { Store.deleteTag($0, in: ctx) } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("Tags")
    }

    private func add() {
        let triggers = newTriggers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        if Store.createTag(newName, triggers: triggers, parent: parent.isEmpty ? nil : parent, in: ctx) == nil {
            error = "That tag already exists."
        } else {
            error = nil; newName = ""; newTriggers = ""; parent = ""
        }
    }
}

struct TagDetail: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable var tag: Tag
    @State private var triggers = ""
    @State private var confirm = false

    var body: some View {
        Form {
            Section("Trigger words") {
                TextField("vet, dog, appointment", text: $triggers)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onSubmit(saveTriggers)
                Text("Any note containing one of these words files itself under #\(tag.name).")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            Section("Color") {
                HStack {
                    ForEach(Tag.palette, id: \.self) { hex in
                        Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(.white, lineWidth: tag.colorHex == hex ? 2 : 0))
                            .onTapGesture { tag.colorHex = hex; try? ctx.save() }
                    }
                }
            }
            Section("Notes (\(tag.notes.count))") {
                ForEach(tag.notes.sorted { $0.createdAt > $1.createdAt }) { n in
                    Text(n.displayText.isEmpty ? n.text : n.displayText).lineLimit(2)
                }
            }
            Section {
                Button("Delete tag", role: .destructive) { confirm = true }
            } footer: {
                Text("#\(tag.name) will be removed from all your notes. The notes themselves will not be deleted.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .navigationTitle("#\(tag.name)")
        .onAppear { triggers = tag.triggerWords.joined(separator: ", ") }
        .onDisappear(perform: saveTriggers)
        .confirmationDialog("Delete #\(tag.name)?", isPresented: $confirm) {
            Button("Delete", role: .destructive) { Store.deleteTag(tag, in: ctx); dismiss() }
        }
    }

    private func saveTriggers() {
        tag.triggerWords = triggers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        try? ctx.save()
    }
}
