import Foundation
import Algorithms

struct BookmarkedVersesModel {
    private var bookmarkedVerseIndices: [Int] = []
    private let userDefaultsKey = "SavedVerses"
    private var bookmarkedVerseIndex = 0

    init() {
        // do nothing
    }

    init(currentRegularVerseIndex: Int) {
        getData()
        initialSetIndex(regularIndex: currentRegularVerseIndex)
    }

    var isEmpty: Bool {
        bookmarkedVerseIndices.isEmpty
    }

    var currentBookmarkedVerseIndex: Int {
        bookmarkedVerseIndices[bookmarkedVerseIndex]
    }

    private mutating func getData() {
        guard let array = UserDefaults.standard.array(forKey: userDefaultsKey) as? [Int] else {
            return
        }
        bookmarkedVerseIndices = array
    }

    func markBookmarked(allVerses: [Verse]) -> [Verse] {
        var modifiedVerses = allVerses
        for index in bookmarkedVerseIndices {
            modifiedVerses[index].bookmarked = true
        }
        return modifiedVerses
    }

    mutating func addVerse(chapter: Int, verse: Int) {
        bookmarkedVerseIndices.insert(VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse), at: bookmarkedVerseIndex)
    }

    mutating func removeCurrentVerse() -> Int {
        let removalIndex = bookmarkedVerseIndices[bookmarkedVerseIndex]
        bookmarkedVerseIndices.remove(at: bookmarkedVerseIndex)
        if bookmarkedVerseIndex > 0 {
            bookmarkedVerseIndex -= 1
        }
        return removalIndex
    }

    func persistData() {
        let array = Array(bookmarkedVerseIndices)
        UserDefaults.standard.setValue(array, forKey: userDefaultsKey)
    }

    mutating func nextVerseIndex() -> Int {
        bookmarkedVerseIndex = (bookmarkedVerseIndex + 1) % bookmarkedVerseIndices.count
        return bookmarkedVerseIndices[bookmarkedVerseIndex]
    }

    mutating func prevVerseIndex() -> Int {
        bookmarkedVerseIndex = ((bookmarkedVerseIndex == 0 ? bookmarkedVerseIndices.count : bookmarkedVerseIndex) - 1) % bookmarkedVerseIndices.count
        return bookmarkedVerseIndices[bookmarkedVerseIndex]
    }

    func currentVerseIndex() -> Int {
        return bookmarkedVerseIndices[bookmarkedVerseIndex]
    }

    mutating func regularVerseIndexUpdate(regularIndex: Int) {
        if bookmarkedVerseIndex + 1 < bookmarkedVerseIndices.count, bookmarkedVerseIndices[bookmarkedVerseIndex + 1] == regularIndex {
            bookmarkedVerseIndex += 1
        }
        if bookmarkedVerseIndex - 1 > 0, bookmarkedVerseIndices[bookmarkedVerseIndex - 1] == regularIndex {
            bookmarkedVerseIndex -= 1
        }
    }

    private mutating func initialSetIndex(regularIndex: Int) {
        if !bookmarkedVerseIndices.isEmpty {
            bookmarkedVerseIndex = bookmarkedVerseIndices.binaryFind(regularIndex)
        }
    }

}


extension Array where Element: Comparable {

//    /// Inserts an element into a sorted array using binary search (partitioning index).
//    /// - Returns: The index where the element was inserted or found.
//    mutating func binaryInsert(_ newElement: Element) -> Int {
//        let index = partitioningIndex { $0 >= newElement }
//        if index >= self.count || self[index] != newElement {
//            self.insert(newElement, at: index)
//        }
//        return index
//    }

//    // Removes an element from a sorted array using binary search (partitioning index).
//    /// - Returns: `true` if the element was found and removed.
//    mutating func binaryRemove(_ element: Element) -> Int? {
//        let index = self.binaryFind(element)
//        guard self[index] == element else {
//            return nil
//        }
//        self.remove(at: index)
//        return index
//    }

    // Returns the element or the closest smaller element
    func binaryFind(_ element: Element) -> Int {
        var index = partitioningIndex { $0 >= element }
        if index < self.count && self[index] == element {
            return index
        }
        if self [index] > element {
            index -= 1
        }
        return [index, 0].max()!
    }

}
