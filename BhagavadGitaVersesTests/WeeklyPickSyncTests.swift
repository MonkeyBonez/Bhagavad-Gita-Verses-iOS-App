import Foundation
import Testing
@testable import Bhagavad_Gita_Verses

struct WeeklyPickSyncTests {
    private let cal = Calendar.current

    @Test func sundayStartLandsOnSundayAtStartOfDay() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let sunday = WeeklyPickSync.sundayStart(for: date)

        #expect(cal.component(.weekday, from: sunday) == 1)         // 1 == Sunday
        #expect(sunday <= date)                                     // never in the future
        #expect(cal.startOfDay(for: sunday) == sunday)              // midnight
        #expect(date.timeIntervalSince(sunday) < 7 * 24 * 3600)     // within the current week
    }

    @Test func nextSundayIsExactlyOneWeekAheadOfCurrent() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let sunday = WeeklyPickSync.sundayStart(for: date)
        let next = WeeklyPickSync.nextSundayStart(after: date)

        #expect(cal.component(.weekday, from: next) == 1)
        #expect(next > sunday)
        let days = cal.dateComponents([.day], from: sunday, to: next).day
        #expect(days == 7)
    }
}
