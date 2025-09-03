import WidgetKit
import SwiftUI

struct VerseWidgetProvider: TimelineProvider {
    private let heuristic: SattvaWeeklyHeuristic = {
        let url = Bundle.main.url(forResource: "verse_to_lesson", withExtension: "json")
        return SattvaWeeklyHeuristic(verseToLessonJSON: url)
    }()
    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(date: Date(), verse: "Wisdom has a way of finding you when you least expect it")
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> ()) {
        let now = Date()
        let pick = WeeklyPickSync.getOrComputePick(forWeekOf: now, with: heuristic)
        let versesReader = VersesReader()
        let verseText = versesReader.verse(atGlobalIndex: VersesInfo.getIndexOfVerse(chapter: pick.chapter, verse: pick.verse)).text
        let entry = VerseEntry(date: now, verse: verseText)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> ()) {
        let now = Date()
        let pick = WeeklyPickSync.getOrComputePick(forWeekOf: now, with: heuristic)
        let versesReader = VersesReader()
        let verseText = versesReader.verse(atGlobalIndex: VersesInfo.getIndexOfVerse(chapter: pick.chapter, verse: pick.verse)).text
        let entry = VerseEntry(date: now, verse: verseText)
        let nextRefresh = WeeklyPickSync.nextSundayStart(after: now)
        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }

}

struct VerseEntry: TimelineEntry {
    let date: Date
    let verse: String
}
