import SwiftUI
import WidgetKit


struct HomescreenVerseWidget: Widget {

    let kind = "HomescreenVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseWidgetProvider()) { entry in
            HomescreenVerseWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemMedium])
        .configurationDisplayName("Verse of the Week")
        .description("Shows the Bhagavad Gita verse of the week.")
    }
}

struct HomescreenVerseWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: VerseWidgetProvider.Entry
    var body: some View {
        Text(entry.verse)
            .multilineTextAlignment(.center)
            .font(.custom(Fonts.verseFontName, size: 20))
            .minimumScaleFactor(10/20)
            .foregroundStyle(textColor)
            .widgetURL(DeeplinkScheme.createDeeplink(path: .homeScreenWidget))
            .containerBackground(for: .widget) {
                backgroundcolor
            }
    }

    var textColor: Color {
        colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment
    }

    var backgroundcolor: LinearGradient {
        colorScheme == .light ? AppColors.parchmentSolidAsGradient : AppColors.peacockBackground
    }
}

#Preview(as: .systemMedium) {
    HomescreenVerseWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}

