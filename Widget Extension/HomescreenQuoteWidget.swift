//
//  HomescreenVerseWidget 2.swift
//  Bhagavad Gita Verses
//
//  Created by Snehal Mulchandani on 6/8/25.
//


import SwiftUI
import WidgetKit


struct HomescreenQuoteWidget: Widget {

    let kind = "HomescreenQuoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteWidgetProvider()) { entry in
            HomescreenQuoteWidgetEntryView(entry: entry)
        }
        .supportedFamilies([.systemSmall])
        .configurationDisplayName("Lesson of the Week")
        .description("Shows the Bhagavad Gita lesson of the week.")
    }
}

struct HomescreenQuoteWidgetEntryView: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: QuoteWidgetProvider.Entry
    var body: some View {
        Text(entry.quote)
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
    QuoteEntry(date: .now, quote: "Act in harmony with your purpose, not to please others.")
    QuoteEntry(date: .now, quote: "Wisdom")
}

