import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var notes: [Note]
    @AppStorage("lightMode") private var lightMode = false
    @AppStorage("fontStyle") private var fontStyle = "system"
    @State private var exportURL: URL?
    @State private var confirmWipe = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Look") {
                    Toggle("Light mode", isOn: $lightMode)
                    Picker("Font", selection: $fontStyle) {
                        Text("System").tag("system")
                        Text("Mono").tag("mono")
                        Text("Serif").tag("serif")
                        Text("Rounded").tag("rounded")
                    }
                }
                Section {
                    NavigationLink("Tags") { TagsView() }
                    NavigationLink("How MindChuk works") { HowItWorks() }
                }
                Section {
                    if let url = exportURL {
                        ShareLink(item: url) { Label("Share notes.csv", systemImage: "square.and.arrow.up") }
                    }
                    Button { export() } label: { Label("Export MindChuk", systemImage: "tablecells") }
                } header: { Text("Your data") } footer: {
                    Text("Download your notes as a clean, organized CSV file. Everything stays on this device; nothing is uploaded anywhere.")
                }
                Section {
                    Link(destination: URL(string: "https://assiamahs.github.io/mindchuk/privacy.html")!) { Label("Privacy Policy", systemImage: "hand.raised") }
                    Link(destination: URL(string: "https://github.com/AssiamahS/mindchuk/issues")!) { Label("Contact Support", systemImage: "questionmark.bubble") }
                }
                Section {
                    Button("Delete all notes", role: .destructive) { confirmWipe = true }
                } footer: {
                    Text("\(notes.count) notes on this device · MindChuk \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete every note?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    notes.forEach { Store.delete($0, in: ctx) }
                }
            } message: { Text("This cannot be undone.") }
        }
    }

    private func export() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MindChuk Notes Export.csv")
        try? Store.csv(notes).data(using: .utf8)?.write(to: url)
        exportURL = url
    }
}

struct HowItWorks: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                step("bubble.left.fill", "Every text becomes a card", "Whatever's on your mind, send it. It'll be here when you need it. No reply back, it just saves.")
                step("number", "A tag's word files it for you", "Write #groceries in a note and it files itself under that tag. Give a tag trigger words (milk, eggs) and those file it too.")
                step("bell.fill", "Start with “remind me” and say when", "“Remind me at 9am to call the vet”, “remind me to call John in 30 minutes”, “on Jan 30 submit report”. MindChuk pings you at that time.")
                step("photo.fill", "Photos and links save too", "Attach a photo with the paperclip. Paste a link and the card shows it ready to open.")
                step("rectangle.split.3x1.fill", "Board, calendar, swipe", "Turn tags into columns, see what's scheduled on any day, or swipe through the deck to sort it out.")
                step("lock.fill", "Private by design", "Everything lives on this iPhone. There's no account, no server, no upload. Export a CSV any time.")
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("How it works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40).background(Theme.card, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
    }
}
