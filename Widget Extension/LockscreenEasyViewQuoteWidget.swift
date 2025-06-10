import WidgetKit
import SwiftUI

struct LockscreenEasyViewQuoteWidgetEntryView: View {
    var entry: QuoteWidgetProvider.Entry
    var body: some View {
        ZStack {
            Text(entry.quote)
                .multilineTextAlignment(.center)
                .font(.custom(Fonts.verseFontName, size: 20))
                .minimumScaleFactor(10/20)
                .padding(.horizontal, 4)
            RoundedRectangle(cornerSize: CGSize(width: 5.0, height: 7.0))
                .opacity(0.18)
        }
        .widgetURL(DeeplinkScheme.createDeeplink(path: .lockScreenWidget))
    }
}

struct LockscreenEasyViewQuoteWidget: Widget {
    let kind: String = "easyViewLockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteWidgetProvider()) { entry in
            LockscreenEasyViewQuoteWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Easy View of Quote of the Week")
        .description("This is a widget to show the quote of the week from the Bhagavad Gita - utilizing a blurred background behind text for easier viewing")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    LockscreenEasyViewQuoteWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "Act in harmony with your purpose, not to please others.")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}
