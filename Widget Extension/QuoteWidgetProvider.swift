import WidgetKit
import SwiftUI

struct QuoteWidgetProvider: TimelineProvider {
    let quoteReader = QuoteReader()
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: "Wisdom has a way of finding you when you least expect it")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> ()) {
        let entry = QuoteEntry(date: Date(), quote: quoteReader.quoteOfDay.text)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> ()) {
        var entries: [QuoteEntry] = []
        let currentDate = Date()
        let firstEntry = QuoteEntry(date: currentDate, quote: quoteReader.quoteOfDay.text)
        entries.append(firstEntry)

        // Generate a timeline consisting of one entries a day apart, starting from the current date.
        //create better logic to predict days that will require updates
        let beginningOfCurrentDate = Calendar.current.startOfDay(for: currentDate)
        for dayOffset in 1 ..< 2 { // TODO: fix to be weekly updates
            guard let entryDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: beginningOfCurrentDate) else {
                return
            }
            let quoteForEntry = quoteReader.quoteOfDayFor(date: entryDate)
            let entry = QuoteEntry(date: entryDate, quote: quoteForEntry.text)
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
