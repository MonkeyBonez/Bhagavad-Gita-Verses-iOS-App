import WidgetKit
import SwiftUI

struct LockscreenQuoteWidgetEntryView: View {
    var entry: QuoteWidgetProvider.Entry
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

struct LockscreenQuoteWidget: Widget {
    let kind: String = "lockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteWidgetProvider()) { entry in
            LockscreenQuoteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quote of the Week")
        .description("This is a widget to show the Quote of the week from the Bhagavad Gita.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    LockscreenQuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "Act in harmony with your purpose, not to please others.")
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}
