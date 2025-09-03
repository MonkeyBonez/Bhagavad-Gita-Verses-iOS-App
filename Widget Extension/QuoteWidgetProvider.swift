import WidgetKit
import SwiftUI

struct QuoteWidgetProvider: TimelineProvider {
    private let heuristic: SattvaWeeklyHeuristic = {
        let url = Bundle.main.url(forResource: "verse_to_lesson", withExtension: "json")
        return SattvaWeeklyHeuristic(verseToLessonJSON: url)
    }()
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: "Wisdom has a way of finding you when you least expect it")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> ()) {
        let now = Date()
        let pick = WeeklyPickSync.getOrComputePick(forWeekOf: now, with: heuristic)
        let entry = QuoteEntry(date: now, quote: pick.lessonText)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> ()) {
        let now = Date()
        let pick = WeeklyPickSync.getOrComputePick(forWeekOf: now, with: heuristic)
        let entry = QuoteEntry(date: now, quote: pick.lessonText)
        let nextRefresh = WeeklyPickSync.nextSundayStart(after: now)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

}

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
}
