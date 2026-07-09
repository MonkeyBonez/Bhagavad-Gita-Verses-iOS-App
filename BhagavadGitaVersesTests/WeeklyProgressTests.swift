import Foundation
import Testing
@testable import Bhagavad_Gita_Verses

struct WeeklyProgressTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)   // a Tuesday
    private let cal = Calendar.current

    /// The anchor `w` weeks before the current week.
    private func anchorBack(_ w: Int) -> Int {
        let cur = WeeklyPickSync.sundayStart(for: now)
        return WeeklyProgress.anchor(for: cal.date(byAdding: .day, value: -7 * w, to: cur)!)
    }

    @Test func anchorMatchesWeeklyPickSync() {
        #expect(WeeklyProgress.anchor(for: now) == Int(WeeklyPickSync.sundayStart(for: now).timeIntervalSince1970))
    }

    @Test func recentEngagementIsOldestToNewestEndingAtCurrentWeek() {
        let opened: Set<Int> = [anchorBack(0), anchorBack(2)]
        let strip = WeeklyProgress.recentEngagement(opened: opened, now: now, count: 4)
        // weeks back: [3,2,1,0] -> engaged at 2 and 0
        #expect(strip == [false, true, false, true])
        #expect(strip.last == true)   // current week is the last element
    }

    @Test func streakCountsCurrentWeekAndConsecutivePast() {
        let opened: Set<Int> = [anchorBack(0), anchorBack(1), anchorBack(2)]
        #expect(WeeklyProgress.currentStreak(opened: opened, now: now) == 3)
    }

    @Test func streakForgivesUnopenedCurrentWeek() {
        // current week NOT opened, but last two were -> streak still alive at 2
        let opened: Set<Int> = [anchorBack(1), anchorBack(2)]
        #expect(WeeklyProgress.currentStreak(opened: opened, now: now) == 2)
    }

    @Test func streakBreaksOnAGap() {
        // current + one back opened, then a gap, then older ones — streak is only 2
        let opened: Set<Int> = [anchorBack(0), anchorBack(1), anchorBack(3), anchorBack(4)]
        #expect(WeeklyProgress.currentStreak(opened: opened, now: now) == 2)
    }

    @Test func streakIsZeroWhenNeitherCurrentNorPriorOpened() {
        let opened: Set<Int> = [anchorBack(2), anchorBack(3)]
        #expect(WeeklyProgress.currentStreak(opened: opened, now: now) == 0)
    }

    @Test func emptyHistoryHasNoStreak() {
        #expect(WeeklyProgress.currentStreak(opened: [], now: now) == 0)
        #expect(WeeklyProgress.recentEngagement(opened: [], now: now, count: 8).allSatisfy { $0 == false })
        #expect(WeeklyProgress.weeksEngaged(opened: []) == 0)
    }

    @Test func weeksEngagedCountsDistinct() {
        #expect(WeeklyProgress.weeksEngaged(opened: [anchorBack(0), anchorBack(5), anchorBack(9)]) == 3)
    }

    @Test func recentAnchorsAreOneWeekApartAndSorted() {
        let a = WeeklyProgress.recentAnchors(now: now, count: 6)
        #expect(a.count == 6)
        // Weekly and strictly increasing. Gaps are ~7 days but can be ±1h across a DST
        // transition, since anchors are DST-safe calendar Sundays, not fixed 604800s intervals.
        let week = 7 * 24 * 3600
        for i in 1..<a.count {
            let gap = a[i] - a[i-1]
            #expect(gap > 0)
            #expect(abs(gap - week) <= 3600)
        }
    }
}
