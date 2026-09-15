import Foundation

/// Turns a raw "text" into the pieces MindChuk cares about:
/// hashtags, trigger words, and a "remind me ..." time.
enum Parser {
    static let reminderPrefixes = ["remind me to ", "remind me ", "reminder: ", "reminder "]

    /// `#word` tags, lowercased, without the `#`.
    static func hashtags(in text: String) -> [String] {
        let pattern = #"(?<![\w&])#([A-Za-z0-9_\-]+)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        var out: [String] = []
        for m in re.matches(in: text, range: range) {
            if let r = Range(m.range(at: 1), in: text) {
                let tag = text[r].lowercased()
                if !out.contains(tag) { out.append(tag) }
            }
        }
        return out
    }

    static func stripHashtags(_ text: String) -> String {
        let pattern = #"(?<![\w&])#[A-Za-z0-9_\-]+\s?"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    /// Words in the text (lowercased) so trigger words can match.
    static func words(in text: String) -> Set<String> {
        Set(text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty })
    }

    static func isReminderText(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return reminderPrefixes.contains { lower.hasPrefix($0) }
    }

    static func stripReminderPrefix(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespaces)
        let lower = t.lowercased()
        for p in reminderPrefixes where lower.hasPrefix(p) {
            t = String(t.dropFirst(p.count))
            break
        }
        return t
    }

    /// Finds a date/time phrase anywhere in the text ("at 9am", "tomorrow 3pm",
    /// "on Jan 30 2027 at 3pm", "in 30 minutes"). Returns the date and the
    /// text with that phrase removed. Times with no day roll to tomorrow if past.
    static func extractDate(from text: String, now: Date = .now) -> (Date, String)? {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = det.matches(in: text, range: range).first, var date = m.date else { return nil }
        if date < now, let bumped = Calendar.current.date(byAdding: .day, value: 1, to: date), m.timeZone == nil {
            // "at 9am" said at 10am means tomorrow 9am
            let sameDay = Calendar.current.isDate(date, inSameDayAs: now)
            if sameDay { date = bumped }
        }
        var cleaned = text
        if let r = Range(m.range, in: text) {
            cleaned.removeSubrange(r)
        }
        // tidy dangling "at", "on", "in" left behind
        cleaned = cleaned.replacingOccurrences(of: #"\s+(at|on|in|by)\s*$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"^\s*(at|on|in|by)\s+"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return (date, cleaned.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    struct Parsed {
        var text: String
        var hashtags: [String]
        var remindAt: Date?
    }

    static func parse(_ raw: String) -> Parsed {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var remindAt: Date?
        if isReminderText(text), let (d, _) = extractDate(from: text) {
            remindAt = d
        }
        return Parsed(text: text, hashtags: hashtags(in: text), remindAt: remindAt)
    }
}
