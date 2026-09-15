import SwiftUI
import SwiftData

@main
struct MindChukApp: App {
    @AppStorage("lightMode") private var lightMode = false
    @AppStorage("seeded") private var seeded = false

    let container: ModelContainer = {
        let schema = Schema([Note.self, Tag.self])
        let demo = ProcessInfo.processInfo.environment["MINDCHUK_DEMO"] == "1"
            || CommandLine.arguments.contains("-demo")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: demo)
        do {
            let c = try ModelContainer(for: schema, configurations: [config])
            if demo {
                Task { @MainActor in Store.seedDemo(in: c.mainContext) }
            }
            return c
        } catch {
            fatalError("MindChuk could not open its database: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(lightMode ? .light : .dark)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage("fontStyle") private var fontStyle = "system"
    @State private var tab: String = RootView.initialTab()

    /// `-tab board` on the command line opens on that tab (CI screenshots use this).
    static func initialTab() -> String {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { return args[i + 1] }
        return "feed"
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Feed", systemImage: "bubble.left.fill", value: "feed") { FeedView() }
            Tab("Board", systemImage: "rectangle.split.3x1.fill", value: "board") { BoardView() }
            Tab("Calendar", systemImage: "calendar", value: "calendar") { CalendarView() }
            Tab("Swipe", systemImage: "hand.draw.fill", value: "swipe") { SwipeView() }
            Tab("Settings", systemImage: "gearshape.fill", value: "settings") { SettingsView() }
        }
        .fontDesign(AppFont.design(fontStyle))
        .onAppear { Reminders.requestPermission() }
    }
}

enum AppFont {
    static func design(_ style: String) -> Font.Design {
        switch style {
        case "mono": return .monospaced
        case "serif": return .serif
        case "rounded": return .rounded
        default: return .default
        }
    }
}
