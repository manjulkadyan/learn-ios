import SwiftUI
import WidgetKit
import AppIntents

struct SyntheticEntry: TimelineEntry {
    let date: Date
    let title: String
}
struct SyntheticProvider: TimelineProvider {
    func placeholder(in context: Context) -> SyntheticEntry { SyntheticEntry(date: .now, title: "Synthetic card") }
    func getSnapshot(in context: Context, completion: @escaping (SyntheticEntry) -> Void) {
        completion(SyntheticEntry(date: .now, title: "Alpha practice card"))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SyntheticEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [SyntheticEntry(date: now, title: "Alpha practice card")],
            policy: .after(now.addingTimeInterval(3600))))
    }
}

struct SyntheticAcknowledgmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Acknowledge synthetic card"
    static var description = IntentDescription("Returns a practice dialog; does not write shared app state.")
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Synthetic acknowledgment only. No data was saved.")
    }
}

struct SyntheticWidgetView: View {
    let entry: SyntheticEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Practice fixture").font(.caption)
            Text(entry.title).font(.headline)
            Button(intent: SyntheticAcknowledgmentIntent()) { Label("Acknowledge", systemImage: "checkmark") }
        }
        .containerBackground(.quaternary, for: .widget)
        .widgetURL(URL(string: "workbench://gallery/item/alpha"))
    }
}

@main
struct SyntheticWidget: Widget {
    let kind = "SwiftUIWorkbench.SyntheticWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SyntheticProvider()) { entry in SyntheticWidgetView(entry: entry) }
            .configurationDisplayName("Synthetic workbench")
            .description("Independent fixtures; no App Group store.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
