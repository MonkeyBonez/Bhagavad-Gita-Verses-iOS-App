import WidgetKit
import SwiftUI

struct VerseWidgetProvider: TimelineProvider {
    let dailyQuoteModel = QuoteModel()
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: Date(), verse: "Wisdom has a way of finding you when you least expect it")
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> ()) {
        let entry = VerseEntry(date: Date(), verse: dailyQuoteModel.quote)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> ()) {
        var entries: [VerseEntry] = []
        let currentDate = Date()
        let firstEntry = VerseEntry(date: currentDate, verse: dailyQuoteModel.quote)
        entries.append(firstEntry)

        // Generate a timeline consisting of one entries a day apart, starting from the current date.
        //create better logic to predict days that will require updates
        let beginningOfCurrentDate = Calendar.current.startOfDay(for: currentDate)
        for dayOffset in 1 ..< 2 {
            guard let entryDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: beginningOfCurrentDate), let verseForEntry = dailyQuoteModel.getVerseForDate(entryDate) else {
                return
            }
            let entry = VerseEntry(date: entryDate, verse: verseForEntry.text)
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .atEnd) //will it just rerun this?
        completion(timeline)
    }

}

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: String
}
