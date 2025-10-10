import Foundation

@MainActor
final class VersePagingViewModel {
    private(set) var model: QuoteModel
    private(set) var dataSource: [Int] = []

    init(model: QuoteModel) {
        self.model = model
    }

    func rebuildDataSource() {
        if model.viewingBookmarked {
            dataSource = model.bookmarkedGlobalIndices
        } else {
            dataSource = Array(0..<model.totalVerseCount)
        }
    }

    func previousIndex(currentIndex: Int) -> Int? {
        guard let currentPos = dataSource.firstIndex(of: currentIndex), currentPos > 0 else { return nil }
        return dataSource[currentPos - 1]
    }

    func nextIndex(currentIndex: Int) -> Int? {
        guard let currentPos = dataSource.firstIndex(of: currentIndex), currentPos + 1 < dataSource.count else { return nil }
        return dataSource[currentPos + 1]
    }

    func toggleBookmarkedOnly(currentIndex: Int) -> Int {
        model.viewingBookmarkedTapped()
        rebuildDataSource()
        var targetIndex = currentIndex
        if model.viewingBookmarked {
            if let nearest = dataSource.min(by: { abs($0 - currentIndex) < abs($1 - currentIndex) }) {
                targetIndex = nearest
            } else if let first = dataSource.first {
                targetIndex = first
            }
        }
        model.setCurrentByGlobalIndex(targetIndex)
        return targetIndex
    }
}


