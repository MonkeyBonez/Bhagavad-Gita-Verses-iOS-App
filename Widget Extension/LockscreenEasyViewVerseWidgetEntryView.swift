import WidgetKit
import SwiftUI

struct LockscreenEasyViewVerseWidgetEntryView: View {
    var entry: WidgetProvider.Entry
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

struct LockscreenEasyViewVerseWidget: Widget {
    let kind: String = "easyViewLockscreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            LockscreenEasyViewVerseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Easy View of Quote of the Week")
        .description("This is a widget to show the quote of the week from the Bhagavad Gita - utlizing a blurred background behind text for easier viewing")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    LockscreenEasyViewVerseWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}
