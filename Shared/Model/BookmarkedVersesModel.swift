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
    
    private var bookmarkArrayNextVerseIndex: Int {
        (bookmarkedVerseIndex + 1) % bookmarkedVerseIndices.count
    }
    
    var nextVerseIndex: Int {
        return bookmarkedVerseIndices[bookmarkArrayNextVerseIndex]
    }
    
    mutating func setNextVerseIndex() -> Int {
        bookmarkedVerseIndex = bookmarkArrayNextVerseIndex
        return bookmarkedVerseIndices[bookmarkedVerseIndex]
    }
    
    private var bookmarkArrayPreviousVerseIndex: Int {
        ((bookmarkedVerseIndex == 0 ? bookmarkedVerseIndices.count : bookmarkedVerseIndex) - 1) % bookmarkedVerseIndices.count
    }
    
    var previousVerseIndex: Int {
        return bookmarkedVerseIndices[bookmarkArrayPreviousVerseIndex]
    }

    mutating func setPrevVerseIndex() -> Int {
        bookmarkedVerseIndex = bookmarkArrayPreviousVerseIndex
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

    // Returns the element or the closest smaller element
    func binaryFind(_ element: Element) -> Int {
        var index = Swift.min(partitioningIndex { $0 >= element }, self.count - 1)
        if 0 <= index, index < self.count && self[index] == element {
            return index
        }
        if index > 0, self [index] > element {
            index -= 1
        }
        return index
    }

}
