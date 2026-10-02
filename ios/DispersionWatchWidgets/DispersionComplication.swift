import SwiftUI
import WidgetKit

struct RoundLauncherEntry: TimelineEntry {
    var date: Date
}

struct RoundLauncherProvider: TimelineProvider {
    func placeholder(in context: Context) -> RoundLauncherEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (RoundLauncherEntry) -> Void) { completion(.init(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RoundLauncherEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

@main
struct DispersionComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DispersionRound", provider: RoundLauncherProvider()) { _ in
            RoundLauncherView()
                .widgetURL(URL(string: "dispersion://round"))
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Dispersion")
        .description("Open your round and mark a shot.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct RoundLauncherView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Dispersion", systemImage: "flag.fill").font(.headline)
                Text("Open your round").font(.caption)
            }
        case .accessoryInline:
            Label("Dispersion", systemImage: "flag.fill")
        default:
            Image(systemName: "flag.fill")
                .font(.title2)
                .widgetAccentable()
                .accessibilityLabel("Open Dispersion")
        }
    }
}
