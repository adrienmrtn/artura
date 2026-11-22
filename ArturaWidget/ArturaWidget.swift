import WidgetKit
import SwiftUI

// The "Artwork of the day" widget. Its views live in Artura/Widget (shared with the app,
// which previews them); the artworks come from the same content.json as the app.

struct DailyEntry: TimelineEntry {
    let date: Date
    let artwork: DailyArtwork?
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: Date(), artwork: DailyCatalog.artwork())
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(DailyEntry(date: Date(), artwork: DailyCatalog.artwork()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        // Today, then one entry at each of the next midnights: the artwork changes with the day.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var entries = [DailyEntry(date: Date(), artwork: DailyCatalog.artwork())]
        for offset in 1...3 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            entries.append(DailyEntry(date: day, artwork: DailyCatalog.artwork(on: day)))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DailyEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry

    private var style: DailyWidgetStyle {
        switch family {
        case .systemSmall: return .small
        case .systemLarge: return .large
        case .accessoryRectangular: return .lockScreen
        default: return .medium
        }
    }

    var body: some View {
        DailyWidgetContent(artwork: entry.artwork, style: style)
            .containerBackground(for: .widget) {
                DailyWidgetBackground(artwork: entry.artwork, style: style)
            }
    }
}

struct DailyArtworkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyArtwork", provider: DailyProvider()) { entry in
            DailyEntryView(entry: entry)
        }
        .configurationDisplayName("Artwork of the day")
        .description("A new masterpiece on your Home Screen, every day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct ArturaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyArtworkWidget()
    }
}
