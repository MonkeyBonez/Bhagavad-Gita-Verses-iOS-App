import Foundation
import Testing
@testable import Bhagavad_Gita_Verses

struct AppGroupMigrationTests {

    // MARK: - Pure merge helpers

    @Test func mergeLegacyIndicesUnionsAndSorts() {
        #expect(AppGroupMigration.mergeBookmarkIndices(source: [5, 1, 3], destination: [3, 4]) == [1, 3, 4, 5])
    }

    @Test func mergeLegacyIndicesHandlesEmpty() {
        #expect(AppGroupMigration.mergeBookmarkIndices(source: [], destination: []) == [])
        #expect(AppGroupMigration.mergeBookmarkIndices(source: [2, 1], destination: []) == [1, 2])
    }

    @Test func mergeV2KeepsEarlierTimestampOnCollision() {
        let src: [AppGroupMigration.BookmarkV2] = [(index: 1, ts: 100), (index: 2, ts: 50)]
        let dst: [AppGroupMigration.BookmarkV2] = [(index: 1, ts: 200), (index: 3, ts: 30)]
        let merged = AppGroupMigration.mergeBookmarksV2(source: src, destination: dst)

        #expect(merged.map { $0.index } == [1, 2, 3])
        let byIndex = Dictionary(uniqueKeysWithValues: merged.map { ($0.index, $0.ts) })
        #expect(byIndex[1] == 100) // earlier of 100 / 200 wins
        #expect(byIndex[2] == 50)
        #expect(byIndex[3] == 30)
    }

    // MARK: - V2 (de)coding

    @Test func v2RoundTripsThroughData() {
        let entries: [AppGroupMigration.BookmarkV2] = [(index: 7, ts: 12345), (index: 2, ts: 1)]
        let data = AppGroupMigration.encodeBookmarksV2(entries)
        #expect(data != nil)
        let decoded = AppGroupMigration.decodeBookmarksV2(data)
        #expect(Set(decoded.map { $0.index }) == [7, 2])
    }

    @Test func decodeNilOrGarbageReturnsEmpty() {
        #expect(AppGroupMigration.decodeBookmarksV2(nil).isEmpty)
        #expect(AppGroupMigration.decodeBookmarksV2(Data([0xFF, 0x00])).isEmpty)
    }

    // MARK: - End-to-end migration against isolated UserDefaults suites

    @Test func migrateUnionsBookmarksFromBothStores() {
        let (src, dst, cleanup) = makeSuites()
        defer { cleanup() }

        src.set([1, 2], forKey: DefaultsKeys.savedVerses)
        dst.set([2, 3], forKey: DefaultsKeys.savedVerses)

        AppGroupMigration.migrate(from: src, to: dst)

        #expect((dst.array(forKey: DefaultsKeys.savedVerses) as? [Int])?.sorted() == [1, 2, 3])
    }

    @Test func migrateCopiesWeeklyPicksOnlyWhenAbsent() {
        let (src, dst, cleanup) = makeSuites()
        defer { cleanup() }

        src.set("srcPick", forKey: DefaultsKeys.weeklyPickPrefix + "111")
        dst.set("dstPick", forKey: DefaultsKeys.weeklyPickPrefix + "222")
        dst.set("keepMe", forKey: DefaultsKeys.weeklyPickPrefix + "111") // already present -> must not be clobbered

        AppGroupMigration.migrate(from: src, to: dst)

        #expect(dst.string(forKey: DefaultsKeys.weeklyPickPrefix + "111") == "keepMe")
        #expect(dst.string(forKey: DefaultsKeys.weeklyPickPrefix + "222") == "dstPick")
    }

    @Test func migrateDoesNotClobberExistingSharedState() {
        let (src, dst, cleanup) = makeSuites()
        defer { cleanup() }

        src.set(Data([1]), forKey: DefaultsKeys.weeklyShownHistory)
        dst.set(Data([2]), forKey: DefaultsKeys.weeklyShownHistory)

        AppGroupMigration.migrate(from: src, to: dst)

        #expect(dst.data(forKey: DefaultsKeys.weeklyShownHistory) == Data([2]))
    }

    // MARK: - Helpers

    private func makeSuites() -> (UserDefaults, UserDefaults, () -> Void) {
        let srcName = "test.src." + UUID().uuidString
        let dstName = "test.dst." + UUID().uuidString
        let src = UserDefaults(suiteName: srcName)!
        let dst = UserDefaults(suiteName: dstName)!
        let cleanup = {
            src.removePersistentDomain(forName: srcName)
            dst.removePersistentDomain(forName: dstName)
        }
        return (src, dst, cleanup)
    }
}
