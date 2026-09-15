import Foundation
import SwiftData
import SwiftUI

@Model
final class Tag {
    @Attribute(.unique) var name: String
    var triggerWords: [String]
    var colorHex: String
    var createdAt: Date
    var parentName: String?
    @Relationship(inverse: \Note.tags) var notes: [Note]

    init(name: String, triggerWords: [String] = [], colorHex: String = "A3E635", parentName: String? = nil) {
        self.name = name
        self.triggerWords = triggerWords
        self.colorHex = colorHex
        self.createdAt = .now
        self.parentName = parentName
        self.notes = []
    }

    var color: Color { Color(hex: colorHex) }

    static let palette = ["A3E635", "C4B5FD", "FB7185", "FDBA74", "38BDF8", "F9A8D4", "34D399", "FCD34D"]
}

@Model
final class Note {
    var id: UUID
    var text: String
    var createdAt: Date
    var remindAt: Date?
    var reminderId: String?
    var isArchived: Bool
    var isDone: Bool
    @Attribute(.externalStorage) var images: [Data]
    var tags: [Tag]

    init(text: String, createdAt: Date = .now, remindAt: Date? = nil, images: [Data] = []) {
        self.id = UUID()
        self.text = text
        self.createdAt = createdAt
        self.remindAt = remindAt
        self.reminderId = nil
        self.isArchived = false
        self.isDone = false
        self.images = images
        self.tags = []
    }

    /// The first http(s) link in the note, if any.
    var link: URL? {
        guard let det = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return det.matches(in: text, options: [], range: range)
            .compactMap { $0.url }
            .first { $0.scheme == "http" || $0.scheme == "https" }
    }

    var isReminder: Bool { remindAt != nil }

    /// Text with the "remind me" prefix and hashtags stripped, for card titles.
    var displayText: String {
        var t = text
        if isReminder { t = Parser.stripReminderPrefix(t) }
        t = Parser.stripHashtags(t)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum Theme {
    static let bg = Color(hex: "0A0A0A")
    static let card = Color(hex: "171717")
    static let cardBorder = Color(hex: "262626")
    static let field = Color(hex: "171717")
    static let muted = Color(hex: "A3A3A3")
    static let dim = Color(hex: "525252")
    static let accent = Color(hex: "A3E635")
    static let danger = Color(hex: "EF4444")
}
