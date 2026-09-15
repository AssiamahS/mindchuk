import Foundation
import SwiftData
import WidgetKit
import ActivityKit

/// Pushes the current notes to the lock screen: keychain snapshot for the
/// widgets + the "Today" Live Activity. Called after every write in Store.
@MainActor
enum LockScreen {
    static let liveActivityKey = "liveActivity"

    static func snapshot(from ctx: ModelContext) -> LockSnapshot {
        let all = ((try? ctx.fetch(FetchDescriptor<Note>())) ?? []).filter { !$0.isArchived }
        let cal = Calendar.current
        let endOfToday = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now
        func item(_ n: Note) -> LockItem {
            let t = n.tags.first
            let txt = n.displayText.isEmpty ? n.text : n.displayText
            return LockItem(id: n.id, text: String(txt.prefix(90)),
                            at: n.remindAt, tag: t?.name, colorHex: t?.colorHex)
        }
        let reminders = all.filter { $0.remindAt != nil && !$0.isDone }
        let due = reminders
            .filter { ($0.remindAt ?? .distantFuture) < endOfToday }
            .sorted { ($0.remindAt ?? .now) < ($1.remindAt ?? .now) }
            .prefix(6).map(item)
        let latest = all
            .filter { $0.remindAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(4).map(item)
        return LockSnapshot(updatedAt: .now, due: Array(due), latest: Array(latest),
                            total: all.count,
                            openReminders: reminders.filter { ($0.remindAt ?? .distantPast) >= .now }.count)
    }

    static func refresh(in ctx: ModelContext) {
        let snap = snapshot(from: ctx)
        SharedStore.save(snap)
        WidgetCenter.shared.reloadAllTimelines()
        if UserDefaults.standard.object(forKey: liveActivityKey) as? Bool ?? true {
            Task { await LiveActivityController.sync(snap) }
        }
    }
}

enum LiveActivityController {
    static var isRunning: Bool { !Activity<TodayAttributes>.activities.isEmpty }

    static func sync(_ snap: LockSnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TodayAttributes.ContentState(due: snap.due, latest: snap.latest,
                                                 openReminders: snap.openReminders, total: snap.total)
        let stale = Calendar.current.date(byAdding: .hour, value: 8, to: .now)
        let content = ActivityContent(state: state, staleDate: stale)
        if let a = Activity<TodayAttributes>.activities.first {
            await a.update(content)
            for extra in Activity<TodayAttributes>.activities.dropFirst() { await extra.end(nil, dismissalPolicy: .immediate) }
        } else {
            _ = try? Activity.request(attributes: TodayAttributes(startedAt: .now), content: content, pushType: nil)
        }
    }

    static func end() async {
        for a in Activity<TodayAttributes>.activities { await a.end(nil, dismissalPolicy: .immediate) }
    }
}
