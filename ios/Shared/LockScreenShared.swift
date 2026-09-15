import Foundation
import ActivityKit
import Security

/// One line on the lock screen: a note or a reminder.
struct LockItem: Codable, Hashable, Identifiable {
    var id: UUID
    var text: String
    var at: Date?
    var tag: String?
    var colorHex: String?
}

/// What the app hands to the widget + Live Activity. Small on purpose:
/// it lives in a keychain item both the app and the extension can read.
struct LockSnapshot: Codable, Hashable {
    var updatedAt: Date
    var due: [LockItem]      // undone reminders due by end of today, overdue first
    var latest: [LockItem]   // newest notes
    var total: Int
    var openReminders: Int

    static let empty = LockSnapshot(updatedAt: .distantPast, due: [], latest: [], total: 0, openReminders: 0)

    var nextDue: LockItem? { due.first { ($0.at ?? .distantPast) >= .now } ?? due.first }
}

/// App ↔ widget hand-off without an App Group: a keychain item in a
/// team-prefixed access group. Every provisioning profile already allows
/// `TEAMID.*`, so nothing has to be registered in the developer portal
/// (App Groups can't be created by the CI's API-key session).
enum SharedStore {
    static let accessGroup = "QGMAWHX827.com.assiamah.mindchuk"
    static let service = "com.assiamah.mindchuk.lockscreen"
    static let account = "snapshot"

    static func save(_ snap: LockSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        if !write(data, group: accessGroup) { _ = write(data, group: nil) }
    }

    static func load() -> LockSnapshot? {
        if let d = read(group: accessGroup) ?? read(group: nil) {
            return try? JSONDecoder().decode(LockSnapshot.self, from: d)
        }
        return nil
    }

    private static func base(_ group: String?) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if let group { q[kSecAttrAccessGroup as String] = group }
        return q
    }

    private static func write(_ data: Data, group: String?) -> Bool {
        var q = base(group)
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        if status != errSecItemNotFound { return false }
        attrs.forEach { q[$0.key] = $0.value }
        return SecItemAdd(q as CFDictionary, nil) == errSecSuccess
    }

    private static func read(group: String?) -> Data? {
        var q = base(group)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }
}

/// The "Today" card on the lock screen / Dynamic Island.
struct TodayAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var due: [LockItem]
        var latest: [LockItem]
        var openReminders: Int
        var total: Int
    }
    var startedAt: Date
}

extension DateFormatter {
    static let lockTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        f.amSymbol = "am"; f.pmSymbol = "pm"
        return f
    }()
}

extension LockItem {
    var timeLabel: String? {
        guard let at else { return nil }
        if Calendar.current.isDateInToday(at) { return DateFormatter.lockTime.string(from: at) }
        if at < .now { return "overdue" }
        return at.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
