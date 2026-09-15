import WidgetKit
import SwiftUI
import ActivityKit

@main
struct MindChukWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TodayLiveActivity()
    }
}

// MARK: - Timeline

struct TodayEntry: TimelineEntry {
    let date: Date
    let snap: LockSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snap: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snap: context.isPreview ? .sample : (SharedStore.load() ?? .empty)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let snap = SharedStore.load() ?? .empty
        let now = Date.now
        var dates: [Date] = [now]
        // re-render when each reminder comes due so "next up" moves along
        for d in snap.due.compactMap(\.at) where d > now { dates.append(d.addingTimeInterval(60)) }
        let cal = Calendar.current
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) { dates.append(midnight) }
        let entries = dates.sorted().prefix(8).map { TodayEntry(date: $0, snap: snap) }
        completion(Timeline(entries: Array(entries), policy: .atEnd))
    }
}

extension LockSnapshot {
    static let sample = LockSnapshot(
        updatedAt: .now,
        due: [LockItem(id: UUID(), text: "Call the vet", at: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now), tag: "vet", colorHex: "A3E635"),
              LockItem(id: UUID(), text: "Submit report", at: Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: .now), tag: nil, colorHex: nil)],
        latest: [LockItem(id: UUID(), text: "Eggs, oat milk, limes", at: nil, tag: "groceries", colorHex: "FDBA74"),
                 LockItem(id: UUID(), text: "Idea: podcast on worst launch days", at: nil, tag: "ideas", colorHex: "C4B5FD")],
        total: 42, openReminders: 2)
}

// MARK: - Widget

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MindChukToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(red: 0.04, green: 0.04, blue: 0.04) }
        }
        .configurationDisplayName("MindChuk Today")
        .description("What you texted yourself: today's reminders and latest notes.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall, .systemMedium])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry
    var snap: LockSnapshot { entry.snap }

    var body: some View {
        switch family {
        case .accessoryInline: inline
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: card
        }
    }

    private var inline: some View {
        Group {
            if let n = snap.nextDue {
                Text("\(Image(systemName: "bell.fill")) \(n.timeLabel ?? "") \(n.text)")
            } else if let l = snap.latest.first {
                Text("\(Image(systemName: "bubble.left.fill")) \(l.text)")
            } else {
                Text("\(Image(systemName: "bubble.left.fill")) Text yourself anything")
            }
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: snap.due.isEmpty ? "bubble.left.fill" : "bell.fill").font(.caption)
                Text("\(snap.due.isEmpty ? snap.total : snap.due.count)").font(.title3.bold())
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left.fill").font(.caption2)
                Text("MindChuk").font(.caption2.bold())
                Spacer(minLength: 0)
                if !snap.due.isEmpty { Text("\(snap.due.count) due").font(.caption2) }
            }
            .widgetAccentable()
            if snap.due.isEmpty && snap.latest.isEmpty {
                Text("Text yourself anything.").font(.caption)
                Text("Find it instantly.").font(.caption2).opacity(0.7)
            } else {
                ForEach(rows(max: 2)) { r in
                    HStack(spacing: 4) {
                        if let t = r.timeLabel { Text(t).font(.caption2.monospacedDigit()).opacity(0.8) }
                        Text(r.text).font(.caption).lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("MindChuk", systemImage: "bubble.left.fill").font(.caption.bold())
                    .foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
                Spacer()
                Text(snap.due.isEmpty ? "\(snap.total) notes" : "\(snap.due.count) due today")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if snap.due.isEmpty && snap.latest.isEmpty {
                Text("Text yourself anything.").font(.subheadline.weight(.semibold))
                Text("Open MindChuk or say “Hey Siri, text MindChuk”.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(rows(max: family == .systemMedium ? 4 : 3)) { r in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Circle().fill(Color(hex: r.colorHex ?? "525252")).frame(width: 6, height: 6)
                        if let t = r.timeLabel { Text(t).font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }
                        Text(r.text).font(.caption).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    private func rows(max: Int) -> [LockItem] {
        Array((snap.due + snap.latest).prefix(max))
    }
}

// MARK: - Live Activity ("Today" card)

struct TodayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodayAttributes.self) { context in
            TodayCard(state: context.state)
                .padding(14)
                .activityBackgroundTint(Color(red: 0.04, green: 0.04, blue: 0.04))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("MindChuk", systemImage: "bubble.left.fill").font(.caption.bold())
                        .foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.due.isEmpty ? "\(context.state.total) notes" : "\(context.state.due.count) due")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TodayCard(state: context.state, compact: true)
                }
            } compactLeading: {
                Image(systemName: context.state.due.isEmpty ? "bubble.left.fill" : "bell.fill")
                    .foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
            } compactTrailing: {
                Text("\(context.state.due.isEmpty ? context.state.total : context.state.due.count)").font(.caption.bold())
            } minimal: {
                Image(systemName: "bubble.left.fill").foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
            }
        }
    }
}

struct TodayCard: View {
    let state: TodayAttributes.ContentState
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !compact {
                HStack {
                    Label("MindChuk · Today", systemImage: "bubble.left.fill").font(.caption.bold())
                        .foregroundStyle(Color(red: 0.64, green: 0.90, blue: 0.21))
                    Spacer()
                    Text(state.due.isEmpty ? "\(state.total) notes" : "\(state.due.count) due").font(.caption2).foregroundStyle(.secondary)
                }
            }
            let rows = Array((state.due + state.latest).prefix(compact ? 2 : 3))
            if rows.isEmpty {
                Text("Text yourself anything. Find it instantly.").font(.subheadline)
            }
            ForEach(rows) { r in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(Color(hex: r.colorHex ?? "525252")).frame(width: 6, height: 6)
                    if let t = r.timeLabel { Text(t).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                    Text(r.text).font(.subheadline).lineLimit(1)
                    if let tag = r.tag { Text("#\(tag)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
        .foregroundStyle(.white)
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255, opacity: 1)
    }
}
