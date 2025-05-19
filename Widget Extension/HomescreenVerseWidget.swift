import SwiftUI
import WidgetKit


struct HomescreenVerseWidget: Widget {
    @Environment(\.colorScheme) private var colorScheme

    let kind = "HomescreenVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetProvider()) { entry in
            HomescreenVerseWidgetEntryView(entry: entry)
                .containerBackground(background, for: .widget)
        }
    }

    var background: LinearGradient {
        colorScheme == .light ? AppColors.parchmentSolidAsGradient : AppColors.charcoalBackground
    }
}

struct HomescreenVerseWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: WidgetProvider.Entry
    var body: some View {
        Text(entry.quote)
            .multilineTextAlignment(.center)
            .font(.custom(Fonts.verseFontName, size: 20))
            .minimumScaleFactor(10/20)
            .foregroundStyle(textColor)
            .widgetURL(DeeplinkScheme.createDeeplink(path: .homeScreenWidget))
    }

    var textColor: Color {
        colorScheme == .light ? AppColors.darkCharcoal : AppColors.parchment
    }
}

#Preview(as: .systemMedium) {
    HomescreenVerseWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}

