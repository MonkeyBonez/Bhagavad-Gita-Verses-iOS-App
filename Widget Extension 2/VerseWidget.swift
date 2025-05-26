import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    let dailyQuoteModel = QuoteModel()
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: "Wisdom has a way of finding you when you least expect it")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> ()) {
        let entry = QuoteEntry(date: Date(), quote: dailyQuoteModel.quote)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [QuoteEntry] = []
        let currentDate = Date()
        let firstEntry = QuoteEntry(date: currentDate, quote: dailyQuoteModel.quote)
        entries.append(firstEntry)
        
        // Generate a timeline consisting of one entries a day apart, starting from the current date.
        let beginningOfCurrentDate = Calendar.current.startOfDay(for: currentDate)
        for dayOffset in 1 ..< 2 {
            guard let entryDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: beginningOfCurrentDate) else {
                return
            }
            dailyQuoteModel.setDate(entryDate)
            let entry = QuoteEntry(date: entryDate, quote: dailyQuoteModel.quote)
            entries.append(entry)
        }
        
        let timeline = Timeline(entries: entries, policy: .atEnd) //will it just rerun this?
        completion(timeline)
    }
    
}

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
}

struct verseWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            Text(entry.quote)
                .multilineTextAlignment(.center)
                .font(.custom(Fonts.verseFontName, size: 20))
                .minimumScaleFactor(10/20)
        }
    }
}

struct verseWidget: Widget {
    let kind: String = "example"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            verseWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview(as: .accessoryRectangular) {
    verseWidget()
} timeline: {
    QuoteEntry(date: .now, quote: "You have the right to perform your duty, but not to the fruits of your actions")
    QuoteEntry(date: .now, quote: "Wisdom")
    QuoteEntry(date: .now, quote: "Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it Wisdom has a way of finding you when you least expect it")
}
