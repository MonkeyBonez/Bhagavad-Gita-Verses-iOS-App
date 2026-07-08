import Testing
@testable import Bhagavad_Gita_Verses

/// Exercises the binary-search Array extension that backs BookmarkedVersesModel navigation.
struct BookmarkBinaryFindTests {
    @Test func findsExactElement() {
        #expect([1, 3, 5, 7, 9].binaryFind(5) == 2)
    }

    @Test func fallsBackToClosestSmaller() {
        #expect([1, 3, 5, 7, 9].binaryFind(6) == 2) // 5 is at index 2
    }

    @Test func belowFirstReturnsZero() {
        #expect([10, 20, 30].binaryFind(5) == 0)
    }

    @Test func aboveLastReturnsLastIndex() {
        #expect([10, 20, 30].binaryFind(99) == 2)
    }
}
