import WidgetKit
import SwiftUI

struct LockscreenVerseWidgetEntryView: View {
    var entry: WidgetProvider.Entry
    var body: some View {
        ZStack {
            Text(entry.quote)
                .multilineTextAlignment(.center)
                .font(.custom(Fonts.verseFontName, size: 20))
                .minimumScaleFactor(10/20)
                .padding(.horizontal, 4)
        }
        .widgetURL(DeeplinkScheme.createDeeplink(path: .lockScreenWidget))
    }
}

struct LockscreenVerseWidget: Widget {
    let kind: String = "lockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            LockscreenVerseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quote of the Week")
        .description("This is a widget to show the quote of the week from the Bhagavad Gita.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    LockscreenVerseWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}
