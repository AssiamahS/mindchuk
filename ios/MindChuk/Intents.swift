import AppIntents
import SwiftData

/// "Text MindChuk" — the way to text the app from anywhere:
/// Siri, the Shortcuts app, the Action button, and a Messages automation
/// ("when I get a message from Me → Text MindChuk with Shortcut Input").
/// Runs in the app process in the background; `LiveActivityIntent` lets it
/// start or update the Today card without the app on screen.
struct AddNoteIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Text MindChuk"
    static let description = IntentDescription(
        "Saves a text as a MindChuk note. #tags file it, \"remind me at 9am to…\" sets a reminder.",
        categoryName: "Notes")
    static let openAppWhenRun = false

    @Parameter(title: "Text", requestValueDialog: "What do you want to text yourself?",
               inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Text \(\.$text) to MindChuk")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let ctx = Persistence.container.mainContext
        guard let note = Store.addNote(text, in: ctx) else {
            throw $text.needsValueError("What do you want to text yourself?")
        }
        var dialog = "Saved to MindChuk"
        if let at = note.remindAt {
            dialog = "Saved. I'll remind you \(at.formatted(.dateTime.weekday(.wide).hour().minute()))."
        } else if !note.tags.isEmpty {
            dialog = "Saved under #\(note.tags.map(\.name).joined(separator: " #"))"
        }
        return .result(value: note.text, dialog: IntentDialog(stringLiteral: dialog))
    }
}

/// Puts the Today card on the lock screen (or refreshes it).
struct ShowTodayIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Show MindChuk on the Lock Screen"
    static let description = IntentDescription("Starts or refreshes the MindChuk Today card on the lock screen.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set(true, forKey: LockScreen.liveActivityKey)
        LockScreen.refresh(in: Persistence.container.mainContext)
        return .result(dialog: "MindChuk is on your lock screen.")
    }
}

struct MindChukShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddNoteIntent(),
            phrases: [
                "Text \(.applicationName)",
                "Text myself in \(.applicationName)",
                "Add a note to \(.applicationName)",
                "Send \(.applicationName) a text",
            ],
            shortTitle: "Text MindChuk",
            systemImageName: "bubble.left.fill")
        AppShortcut(
            intent: ShowTodayIntent(),
            phrases: ["Show \(.applicationName) on my lock screen", "Put \(.applicationName) on the lock screen"],
            shortTitle: "Lock screen card",
            systemImageName: "lock.fill")
    }
}
