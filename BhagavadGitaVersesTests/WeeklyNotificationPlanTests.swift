import Foundation
import Testing
@testable import Bhagavad_Gita_Verses

struct WeeklyNotificationPlanTests {

    // A mid-week reference point (this is a Tuesday in most zones).
    private let midWeek = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - desiredEntries shape

    @Test func producesTwentySixDistinctIncreasingEntries() {
        let entries = WeeklyNotificationPlan.desiredEntries(now: midWeek)
        #expect(entries.count == 26)
        #expect(Set(entries.map { $0.id }).count == 26)
        #expect(entries.allSatisfy { $0.id.hasPrefix("regular_") })

        let dates = entries.map { $0.fireDate }
        #expect(dates == dates.sorted())
    }

    @Test func honorsCustomWeekCount() {
        #expect(WeeklyNotificationPlan.desiredEntries(now: midWeek, weeks: 4).count == 4)
    }

    @Test func everyEntryFiresSundayNineAmInFuture() {
        let cal = Calendar.current
        for entry in WeeklyNotificationPlan.desiredEntries(now: midWeek) {
            let comps = cal.dateComponents([.weekday, .hour, .minute], from: entry.fireDate)
            #expect(comps.weekday == 1)   // Sunday
            #expect(comps.hour == 9)
            #expect(comps.minute == 0)
            #expect(entry.fireDate > midWeek)
        }
    }

    // MARK: - Current week excluded / starts next Sunday

    @Test func firstEntryIsNextSundayAndCurrentWeekExcluded() {
        // Test across mid-week, pre-9am Sunday, and post-9am Sunday.
        for now in [midWeek, sundayAt(hour: 0, minute: 30), sundayAt(hour: 10, minute: 0)] {
            let entries = WeeklyNotificationPlan.desiredEntries(now: now)
            let nextAnchor = WeeklyPickSync.nextSundayStart(after: now)
            #expect(entries.first?.id == WeeklyNotificationPlan.id(forAnchor: nextAnchor))

            let ids = Set(entries.map { $0.id })
            #expect(!ids.contains(WeeklyNotificationPlan.currentWeekId(now: now)))
        }
    }

    // MARK: - Parity with WeeklyPickSync anchor math

    @Test func sundayStartMatchesWeeklyPickSync() {
        for offsetDays in stride(from: 0, to: 365, by: 37) {
            let d = midWeek.addingTimeInterval(TimeInterval(offsetDays) * 24 * 3600)
            #expect(WeeklyNotificationPlan.sundayStart(for: d) == WeeklyPickSync.sundayStart(for: d))
        }
    }

    // MARK: - Intra-week stability

    @Test func sameWeekProducesIdenticalIdSets() {
        let cal = Calendar.current
        let sunday = WeeklyPickSync.sundayStart(for: midWeek)
        let monday = cal.date(byAdding: .day, value: 1, to: sunday)!
        let saturday = cal.date(byAdding: .day, value: 6, to: sunday)!

        let mondayIds = Set(WeeklyNotificationPlan.desiredEntries(now: monday).map { $0.id })
        let saturdayIds = Set(WeeklyNotificationPlan.desiredEntries(now: saturday).map { $0.id })
        #expect(mondayIds == saturdayIds)
    }

    @Test func weekRolloverRemovesExactlyTheNewCurrentWeek() {
        let cal = Calendar.current
        let sunday = WeeklyPickSync.sundayStart(for: midWeek)
        let saturday2359 = cal.date(byAdding: .day, value: 6, to: sunday)!.addingTimeInterval(23 * 3600 + 59 * 60)
        let nextSunday0001 = cal.date(byAdding: .day, value: 7, to: sunday)!.addingTimeInterval(60)

        let pendingIds = WeeklyNotificationPlan.desiredEntries(now: saturday2359).map { $0.id }
        let desiredIds = Set(WeeklyNotificationPlan.desiredEntries(now: nextSunday0001).map { $0.id })

        let removed = WeeklyNotificationPlan.idsToRemove(pendingIds: pendingIds, desiredIds: desiredIds)
        // The only pending ID no longer desired is the week that just became "current".
        #expect(removed == [WeeklyNotificationPlan.currentWeekId(now: nextSunday0001)])
    }

    // MARK: - DST

    @Test func springForwardSundayStillFiresNineAmLocal() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // Feb 2026 → horizon spans the 2026-03-08 spring-forward Sunday.
        let feb = date(2026, 2, 3, cal: cal)
        assertAllNineAmLocal(now: feb, cal: cal)
        assertConsecutiveAnchorsSevenDaysApart(now: feb, cal: cal)
    }

    @Test func fallBackSundayStillFiresNineAmLocal() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // Sep 2026 → horizon spans the 2026-11-01 fall-back Sunday.
        let sep = date(2026, 9, 1, cal: cal)
        assertAllNineAmLocal(now: sep, cal: cal)
        assertConsecutiveAnchorsSevenDaysApart(now: sep, cal: cal)
    }

    @Test func idsStableAcrossDstTransition() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        // Two horizons that both still contain the spring-forward Sunday (2026-03-08): its ID
        // must be identical in both, i.e. the anchor epoch is independent of the horizon's start.
        let earlier = date(2026, 2, 22, cal: cal) // Sunday; horizon = Mar 1, Mar 8, ...
        let later = date(2026, 3, 1, cal: cal)     // Sunday; horizon = Mar 8, ...
        let earlierIds = Set(WeeklyNotificationPlan.desiredEntries(now: earlier, calendar: cal).map { $0.id })
        let laterIds = Set(WeeklyNotificationPlan.desiredEntries(now: later, calendar: cal).map { $0.id })

        let transitionAnchor = WeeklyNotificationPlan.sundayStart(for: date(2026, 3, 8, hour: 12, cal: cal), calendar: cal)
        let transitionId = WeeklyNotificationPlan.id(forAnchor: transitionAnchor)
        #expect(earlierIds.contains(transitionId))
        #expect(laterIds.contains(transitionId))
    }

    // MARK: - idsToRemove

    @Test func emptyPendingRemovesNothing() {
        #expect(WeeklyNotificationPlan.idsToRemove(pendingIds: [], desiredIds: ["regular_1"]).isEmpty)
    }

    @Test func foreignIdsNeverRemoved() {
        let pending = ["daily_quote_1", "com.other.thing", "regular_999"]
        let removed = WeeklyNotificationPlan.idsToRemove(pendingIds: pending, desiredIds: [])
        #expect(!removed.contains("daily_quote_1"))
        #expect(!removed.contains("com.other.thing"))
        #expect(removed.contains("regular_999"))
    }

    @Test func legacyAndStreakAlwaysPruned() {
        let desired = Set(WeeklyNotificationPlan.desiredEntries(now: midWeek).map { $0.id })
        let pending = Array(desired) + ["weekly_lesson_reminder_123", "streak_456"]
        let removed = WeeklyNotificationPlan.idsToRemove(pendingIds: pending, desiredIds: desired)
        #expect(removed.contains("weekly_lesson_reminder_123"))
        #expect(removed.contains("streak_456"))
        // Desired regulars are kept.
        #expect(removed.allSatisfy { !desired.contains($0) })
    }

    @Test func staleAndCurrentWeekRegularsPrunedDesiredKept() {
        let desired = WeeklyNotificationPlan.desiredEntries(now: midWeek).map { $0.id }
        let keptDesired = desired.first!
        let currentWeek = WeeklyNotificationPlan.currentWeekId(now: midWeek)
        let outOfHorizon = "regular_1"  // far past, not in desired
        let pending = [keptDesired, currentWeek, outOfHorizon]

        let removed = Set(WeeklyNotificationPlan.idsToRemove(pendingIds: pending, desiredIds: Set(desired)))
        #expect(removed == [currentWeek, outOfHorizon])
    }

    @Test func emptyDesiredSweepsAllAndOnlyManaged() {
        let pending = ["regular_1", "streak_2", "weekly_lesson_reminder_3", "foreign_4", "x"]
        let removed = Set(WeeklyNotificationPlan.idsToRemove(pendingIds: pending, desiredIds: []))
        #expect(removed == ["regular_1", "streak_2", "weekly_lesson_reminder_3"])
    }

    @Test func currentWeekIdMatchesWeeklyPickSyncAnchor() {
        let expected = "regular_" + String(Int(WeeklyPickSync.sundayStart(for: midWeek).timeIntervalSince1970))
        #expect(WeeklyNotificationPlan.currentWeekId(now: midWeek) == expected)
    }

    // MARK: - Helpers

    private func sundayAt(hour: Int, minute: Int) -> Date {
        let cal = Calendar.current
        let sunday = WeeklyPickSync.sundayStart(for: midWeek)
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: sunday)!
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, cal: Calendar) -> Date {
        var dc = DateComponents()
        dc.year = y; dc.month = m; dc.day = d; dc.hour = hour
        return cal.date(from: dc)!
    }

    private func assertAllNineAmLocal(now: Date, cal: Calendar) {
        for entry in WeeklyNotificationPlan.desiredEntries(now: now, calendar: cal) {
            let comps = cal.dateComponents([.weekday, .hour, .minute], from: entry.fireDate)
            #expect(comps.weekday == 1)
            #expect(comps.hour == 9)
            #expect(comps.minute == 0)
        }
    }

    private func assertConsecutiveAnchorsSevenDaysApart(now: Date, cal: Calendar) {
        let entries = WeeklyNotificationPlan.desiredEntries(now: now, calendar: cal)
        for i in 1..<entries.count {
            let days = cal.dateComponents([.day], from: entries[i - 1].fireDate, to: entries[i].fireDate).day
            #expect(days == 7)
        }
    }
}
