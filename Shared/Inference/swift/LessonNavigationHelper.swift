import Foundation

public enum LessonNavigationHelper {
    // Keep in sync with animation durations used in VerseView
    public static let awayDuration: Double = 0.8

    public static func pickRandomTarget(from units: [UnitRange]) -> (chapter: Int, verse: Int)? {
        guard !units.isEmpty else { return nil }
        let idx = Int.random(in: 0..<units.count)
        let u = units[idx]
        return (u.chapter, u.start)
    }

    public static func globalIndex(forChapter chapter: Int, verse: Int) -> Int {
        return VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse)
    }

    // Pick an index from the top results with weighted randomness.
    // Default weights: [0.5, 0.3, 0.2] for top 3. If fewer than 3, renormalize prefix.
    public static func pickWeightedTopIndex(count: Int, weights: [Double] = [0.5, 0.3, 0.2]) -> Int {
        guard count > 0 else { return 0 }
        let capped = max(1, min(count, weights.count))
        let slice = Array(weights.prefix(capped))
        let total = slice.reduce(0.0, +)
        let normalized = slice.map { $0 / total }
        let r = Double.random(in: 0..<1)
        var acc = 0.0
        for (i, w) in normalized.enumerated() {
            acc += w
            if r < acc { return i }
        }
        return capped - 1
    }
}


