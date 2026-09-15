import Foundation
import SwiftData
import UserNotifications

/// Everything that writes to the database goes through here so the
/// feed, board, swipe deck and calendar all agree.
@MainActor
enum Store {
    @discardableResult
    static func addNote(_ raw: String, images: [Data] = [], in ctx: ModelContext) -> Note? {
        let parsed = Parser.parse(raw)
        guard !parsed.text.isEmpty || !images.isEmpty else { return nil }
        let note = Note(text: parsed.text, remindAt: parsed.remindAt, images: images)
        ctx.insert(note)
        attachTags(to: note, in: ctx)
        if note.remindAt != nil { Reminders.schedule(note) }
        try? ctx.save()
        return note
    }

    /// Files a note under every tag that matches a hashtag or a trigger word.
    static func attachTags(to note: Note, in ctx: ModelContext) {
        let tagNames = Parser.hashtags(in: note.text)
        let words = Parser.words(in: note.text)
        let all = (try? ctx.fetch(FetchDescriptor<Tag>())) ?? []
        var matched: [Tag] = []
        for name in tagNames {
            if let t = all.first(where: { $0.name == name }) {
                matched.append(t)
            } else {
                let t = Tag(name: name, colorHex: Tag.palette[all.count % Tag.palette.count])
                ctx.insert(t)
                matched.append(t)
            }
        }
        for t in all where !matched.contains(where: { $0.name == t.name }) {
            if t.triggerWords.contains(where: { words.contains($0.lowercased()) }) { matched.append(t) }
        }
        note.tags = matched
    }

    static func update(_ note: Note, text: String, in ctx: ModelContext) {
        let parsed = Parser.parse(text)
        note.text = parsed.text
        if parsed.remindAt != nil { note.remindAt = parsed.remindAt }
        attachTags(to: note, in: ctx)
        if note.remindAt != nil { Reminders.schedule(note) }
        try? ctx.save()
    }

    static func setReminder(_ note: Note, at date: Date?, in ctx: ModelContext) {
        note.remindAt = date
        if date == nil { Reminders.cancel(note) } else { Reminders.schedule(note) }
        try? ctx.save()
    }

    static func delete(_ note: Note, in ctx: ModelContext) {
        Reminders.cancel(note)
        ctx.delete(note)
        try? ctx.save()
    }

    static func tag(named name: String, in ctx: ModelContext) -> Tag? {
        let n = name.lowercased()
        return try? ctx.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.name == n })).first
    }

    @discardableResult
    static func createTag(_ name: String, triggers: [String] = [], parent: String? = nil, in ctx: ModelContext) -> Tag? {
        let clean = name.lowercased()
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: " ", with: "-")
        guard !clean.isEmpty, tag(named: clean, in: ctx) == nil else { return nil }
        let count = (try? ctx.fetchCount(FetchDescriptor<Tag>())) ?? 0
        let t = Tag(name: clean, triggerWords: triggers, colorHex: Tag.palette[count % Tag.palette.count], parentName: parent)
        ctx.insert(t)
        // retro-file existing notes that mention the tag or its triggers
        let notes = (try? ctx.fetch(FetchDescriptor<Note>())) ?? []
        for n in notes {
            let words = Parser.words(in: n.text)
            if Parser.hashtags(in: n.text).contains(clean) || triggers.contains(where: { words.contains($0.lowercased()) }) {
                if !n.tags.contains(where: { $0.name == clean }) { n.tags.append(t) }
            }
        }
        try? ctx.save()
        return t
    }

    static func deleteTag(_ t: Tag, in ctx: ModelContext) {
        for n in t.notes { n.tags.removeAll { $0.name == t.name } }
        ctx.delete(t)
        try? ctx.save()
    }

    static func csv(_ notes: [Note]) -> String {
        func q(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let f = ISO8601DateFormatter()
        var out = "created_at,text,tags,remind_at,archived,done\n"
        for n in notes.sorted(by: { $0.createdAt < $1.createdAt }) {
            out += [f.string(from: n.createdAt), q(n.text), q(n.tags.map(\.name).joined(separator: " ")),
                    n.remindAt.map(f.string(from:)) ?? "", n.isArchived ? "1" : "0", n.isDone ? "1" : "0"].joined(separator: ",") + "\n"
        }
        return out
    }

    // MARK: demo data (CI screenshots + first-run "how it works")
    static func seedDemo(in ctx: ModelContext) {
        let cal = Calendar.current
        let now = Date.now
        func ago(_ h: Int) -> Date { cal.date(byAdding: .hour, value: -h, to: now) ?? now }
        createTag("vet", triggers: ["vet", "dog"], in: ctx)
        createTag("travel", triggers: ["flight", "flights", "trip"], in: ctx)
        createTag("groceries", triggers: ["grocery", "milk", "eggs"], in: ctx)
        createTag("ideas", in: ctx)
        let samples: [(String, Int)] = [
            ("Idea: podcast on worst launch days #ideas", 30),
            ("Vet opens at 8 on Saturdays", 26),
            ("Flights for the June trip https://www.google.com/travel/flights", 22),
            ("Eggs, oat milk, limes, hot sauce #groceries", 9),
            ("The best interface is the one you already open 40 times a day. #ideas", 5),
            ("Remind me at 9am to call the vet", 1),
        ]
        for (t, h) in samples {
            let parsed = Parser.parse(t)
            let n = Note(text: parsed.text, createdAt: ago(h), remindAt: parsed.remindAt)
            if parsed.remindAt == nil, Parser.isReminderText(t) {
                n.remindAt = cal.date(bySettingHour: 9, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: now) ?? now)
            }
            ctx.insert(n)
            attachTags(to: n, in: ctx)
        }
        try? ctx.save()
        UserDefaults.standard.set("ideas,groceries,travel", forKey: "boardColumns")
        UserDefaults.standard.set("ideas", forKey: "swipeFinishTag")
    }
}

enum Reminders {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func schedule(_ note: Note) {
        guard let date = note.remindAt, date > .now else { return }
        cancel(note)
        let id = note.id.uuidString
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = note.displayText.isEmpty ? note.text : note.displayText
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        note.reminderId = id
    }

    static func cancel(_ note: Note) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [note.id.uuidString])
        note.reminderId = nil
    }
}
