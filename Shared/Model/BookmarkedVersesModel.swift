import Foundation
import Algorithms

struct BookmarkedVersesModel {
    private var bookmarkedVerseIndices: [Int] = []
    private var indexToTimestamp: [Int: TimeInterval] = [:]
    private let userDefaultsKey = "SavedVerses"
    private let userDefaultsKeyV2 = "SavedVersesV2"
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

    // Expose a copy of all bookmarked indices for read-only consumers (e.g., UI data sources)
    var allIndices: [Int] {
        Array(bookmarkedVerseIndices)
    }

    // Set current bookmarked pointer to the given global verse index if present
    mutating func setCurrentToGlobalIndex(_ globalIndex: Int) {
        if let idx = bookmarkedVerseIndices.firstIndex(of: globalIndex) {
            bookmarkedVerseIndex = idx
        }
    }

    private mutating func getData() {
        if let data = SharedDefaults.defaults.data(forKey: userDefaultsKeyV2),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var indices: [Int] = []
            var tsMap: [Int: TimeInterval] = [:]
            for obj in arr {
                if let idx = obj["index"] as? Int {
                    indices.append(idx)
                    if let ts = obj["ts"] as? TimeInterval { tsMap[idx] = ts }
                }
            }
            bookmarkedVerseIndices = indices
            indexToTimestamp = tsMap
            return
        }
        if let array = SharedDefaults.defaults.array(forKey: userDefaultsKey) as? [Int] {
            bookmarkedVerseIndices = array
            let now = Date().timeIntervalSince1970
            for idx in array { indexToTimestamp[idx] = now }
        }
    }

    func markBookmarked(allVerses: [Verse]) -> [Verse] {
        var modifiedVerses = allVerses
        for index in bookmarkedVerseIndices {
            modifiedVerses[index].bookmarked = true
        }
        return modifiedVerses
    }

    mutating func addVerse(chapter: Int, verse: Int) {
        let globalIndex = VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse)
        // If already bookmarked, move pointer to that entry and return
        if let existing = bookmarkedVerseIndices.firstIndex(of: globalIndex) {
            bookmarkedVerseIndex = existing
            // Do not change timestamp for existing bookmark
            return
        }
        // Insert in sorted order using binary search (partitioningIndex)
        let insertPos = bookmarkedVerseIndices.partitioningIndex { $0 >= globalIndex }
        bookmarkedVerseIndices.insert(globalIndex, at: insertPos)
        indexToTimestamp[globalIndex] = Date().timeIntervalSince1970
        bookmarkedVerseIndex = insertPos
    }

    mutating func removeCurrentVerse() -> Int {
        let removalIndex = bookmarkedVerseIndices[bookmarkedVerseIndex]
        bookmarkedVerseIndices.remove(at: bookmarkedVerseIndex)
        indexToTimestamp.removeValue(forKey: removalIndex)
        if bookmarkedVerseIndex > 0 {
            bookmarkedVerseIndex -= 1
        }
        return removalIndex
    }

    func persistData() {
        let array = Array(bookmarkedVerseIndices)
        SharedDefaults.defaults.setValue(array, forKey: userDefaultsKey)
        var v2: [[String: Any]] = []
        v2.reserveCapacity(array.count)
        for idx in array {
            let ts = indexToTimestamp[idx] ?? Date().timeIntervalSince1970
            v2.append(["index": idx, "ts": ts])
        }
        if let data = try? JSONSerialization.data(withJSONObject: v2) {
            SharedDefaults.defaults.set(data, forKey: userDefaultsKeyV2)
        }
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

    // Set pointer to the nearest bookmarked verse to the given global index and return that global index
    mutating func setPointerToNearest(to regularIndex: Int) -> Int? {
        guard !bookmarkedVerseIndices.isEmpty else { return nil }
        let pos = bookmarkedVerseIndices.partitioningIndex { $0 >= regularIndex }
        let chosenIdx: Int
        if pos == 0 {
            chosenIdx = 0
        } else if pos >= bookmarkedVerseIndices.count {
            chosenIdx = bookmarkedVerseIndices.count - 1
        } else {
            let prevIdx = pos - 1
            let nextIdx = pos
            let prevVal = bookmarkedVerseIndices[prevIdx]
            let nextVal = bookmarkedVerseIndices[nextIdx]
            chosenIdx = (regularIndex - prevVal) <= (nextVal - regularIndex) ? prevIdx : nextIdx
        }
        bookmarkedVerseIndex = chosenIdx
        return bookmarkedVerseIndices[chosenIdx]
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
