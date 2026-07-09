import Foundation

/// Pure engagement math over the set of "weeks the user opened the app" (Sunday-anchor
/// epoch seconds, the same anchors `WeeklyPickSync`/`WeeklyNotificationPlan` use).
/// No I/O — fully unit-testable.
enum WeeklyProgress {

    /// The Sunday-anchor epoch (seconds) for the week containing `date`.
    static func anchor(for date: Date) -> Int {
        Int(WeeklyPickSync.sundayStart(for: date).timeIntervalSince1970)
    }

    /// Week anchors going back `count` weeks, oldest → newest (last element = current week).
    static func recentAnchors(now: Date, count: Int, calendar: Calendar = .current) -> [Int] {
        let current = WeeklyPickSync.sundayStart(for: now)
        var out: [Int] = []
        for i in stride(from: count - 1, through: 0, by: -1) {
            if let d = calendar.date(byAdding: .day, value: -7 * i, to: current) {
                out.append(anchor(for: d))
            }
        }
        return out
    }

    /// For a strip of the last `count` weeks: whether each was opened (oldest → newest).
    static func recentEngagement(opened: Set<Int>, now: Date, count: Int, calendar: Calendar = .current) -> [Bool] {
        recentAnchors(now: now, count: count, calendar: calendar).map { opened.contains($0) }
    }

    /// Consecutive weeks of engagement ending at the current week — forgiving of the current
    /// week not being opened *yet*: if this week isn't open but last week was, the streak still
    /// counts from last week (it only breaks once a full week is missed).
    static func currentStreak(opened: Set<Int>, now: Date, calendar: Calendar = .current) -> Int {
        let current = WeeklyPickSync.sundayStart(for: now)
        let curAnchor = anchor(for: current)
        var endpoint: Date
        if opened.contains(curAnchor) {
            endpoint = current
        } else if let prev = calendar.date(byAdding: .day, value: -7, to: current),
                  opened.contains(anchor(for: prev)) {
            endpoint = prev
        } else {
            return 0
        }
        var streak = 0
        var week: Date? = endpoint
        while let w = week, opened.contains(anchor(for: w)) {
            streak += 1
            week = calendar.date(byAdding: .day, value: -7, to: w)
        }
        return streak
    }

    /// Total distinct weeks the user has ever shown up.
    static func weeksEngaged(opened: Set<Int>) -> Int { opened.count }
}

/// Thin store for the weekly-engagement history in the App Group. Recording is independent of
/// notification permission so progress accrues for every user, on every app open.
enum WeeklyEngagement {
    static func openedAnchors() -> Set<Int> {
        if let arr = SharedDefaults.defaults.array(forKey: DefaultsKeys.openedWeekAnchors) as? [Int] {
            return Set(arr)
        }
        return []
    }

    /// Marks the current week as engaged. Idempotent (set insert). Safe to call every launch.
    @discardableResult
    static func recordCurrentWeekOpen(now: Date = Date()) -> Set<Int> {
        var set = openedAnchors()
        set.insert(WeeklyProgress.anchor(for: now))
        SharedDefaults.defaults.set(Array(set), forKey: DefaultsKeys.openedWeekAnchors)
        return set
    }
}
