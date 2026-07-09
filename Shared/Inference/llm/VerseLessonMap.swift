import Foundation

/// Looks up the app's mapped one-line lesson for a specific verse, from the bundled
/// `verse_to_lesson.json` ("ch:vs" → lesson index) + `lessons_meta.json` (index → text) —
/// the same assets the weekly heuristic and retriever already ship. Loaded once, cached.
///
/// This is what lets the explanation surface ground itself in the lesson (and what the
/// stub streams when no on-device model is available) instead of receiving `lesson: nil`.
enum VerseLessonMap {
    private static let store: (map: [String: Int], lessons: LessonTextsIndex?) = {
        var map: [String: Int] = [:]
        if let url = Bundle.main.url(forResource: "verse_to_lesson", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Int] {
            map = parsed
        }
        return (map, LessonTextsIndex())
    }()

    static func lesson(chapter: Int, verse: Int) -> String? {
        guard let lessons = store.lessons,
              let idx = store.map["\(chapter):\(verse)"],
              idx >= 0, idx < lessons.count else { return nil }
        return lessons.text(forIndex: idx)
    }
}
