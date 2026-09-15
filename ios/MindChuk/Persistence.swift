import Foundation
import SwiftData

/// One container for the app, its App Intents (Siri / Shortcuts / Messages
/// automation) and the lock-screen refresh. Demo mode (CI screenshots) is in-memory.
enum Persistence {
    static let isDemo: Bool = ProcessInfo.processInfo.environment["MINDCHUK_DEMO"] == "1"
        || CommandLine.arguments.contains("-demo")

    static let container: ModelContainer = {
        let schema = Schema([Note.self, Tag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isDemo)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("MindChuk could not open its database: \(error)")
        }
    }()
}
