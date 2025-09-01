import Foundation

struct VersesReader {
    let versesFilePath = Bundle.main.path(forResource: "verses-formatted", ofType: "json")
    let quoteReader = QuoteReader()
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verses: [Verse]
    var currentVerse: Verse
    var bookmarkedVersesModel: BookmarkedVersesModel = BookmarkedVersesModel()
    var bookmarkedOnlyMode: Bool = false {
        didSet {
            checkValidBookmarkOnlyMode()
            if bookmarkedOnlyMode {
                // When entering bookmarked mode, jump to the nearest bookmarked verse to the current regular index
                let current = VersesInfo.getIndexOfVerse(chapter: chapterNumber, verse: verseNumber)
                if let nearest = bookmarkedVersesModel.setPointerToNearest(to: current) {
                    currentVerse = verses[nearest]
                } else {
                    getCurrentBookmarkedVerse()
                }
            }
            if !bookmarkedOnlyMode {
                updateVerse(chapter: chapterNumber, verse: verseNumber)
            }
        }
    }

    init(currentVerse: Verse = Verse(text: "", chapterNumber: 0, verseNumber: 0)) {
        self.currentVerse = currentVerse
        verses = []
        guard let verses = FileReader.getVerses(filePath: versesFilePath) else {
            return
        }
        (chapterNumber, verseNumber) = getChapterAndVerseNumber(for: Date())
        self.bookmarkedVersesModel = BookmarkedVersesModel(currentRegularVerseIndex: VersesInfo.getIndexOfVerse(chapter: chapterNumber, verse: verseNumber))
        self.verses = bookmarkedVersesModel.markBookmarked(allVerses: verses)
        self.currentVerse = getVerse(chapter: chapterNumber, verse: verseNumber)
    }

    private mutating func checkValidBookmarkOnlyMode() {
        if bookmarkedOnlyMode, bookmarkedVersesModel.isEmpty {
            bookmarkedOnlyMode = false
        }
    }

    var hasBookmarks: Bool {
        !bookmarkedVersesModel.isEmpty
    }

    private func getVerse(chapter: Int, verse: Int) -> Verse {
        verses[VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse)]
    }

    private mutating func updateVerse(chapter: Int, verse: Int){
        let index = VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse)
        bookmarkedVersesModel.regularVerseIndexUpdate(regularIndex: index)
        currentVerse = verses[VersesInfo.getIndexOfVerse(chapter: chapter, verse: verse)]
    }

    // MARK: - New helpers for paging UI
    var totalVerseCount: Int {
        verses.count
    }

    var currentGlobalIndex: Int {
        VersesInfo.getIndexOfVerse(chapter: chapterNumber, verse: verseNumber)
    }

    var bookmarkedGlobalIndices: [Int] {
        bookmarkedVersesModel.allIndices
    }

    mutating func setCurrentByGlobalIndex(_ index: Int) {
        guard index >= 0 && index < verses.count else { return }
        // Map index back to chapter/verse
        var remaining = index
        var newChapter = 1
        for count in VersesInfo.versesPerChapter {
            if remaining < count { break }
            remaining -= count
            newChapter += 1
        }
        let newVerse = remaining + 1
        chapterNumber = newChapter
        verseNumber = newVerse
        updateVerse(chapter: chapterNumber, verse: verseNumber)
        // Keep bookmarked pointer in sync
        bookmarkedVersesModel.setCurrentToGlobalIndex(index)
    }

    mutating func setCurrentByChapterVerse(_ chapter: Int, _ verse: Int) {
        guard chapter > 0, chapter <= VersesInfo.versesPerChapter.count else { return }
        guard verse > 0, verse <= VersesInfo.versesPerChapter[chapter - 1] else { return }
        chapterNumber = chapter
        verseNumber = verse
        updateVerse(chapter: chapterNumber, verse: verseNumber)
    }

    func verse(atGlobalIndex index: Int) -> Verse {
        verses[max(0, min(index, verses.count - 1))]
    }

    private var verseOfDay: Verse {
        verseOfDayForDate(Date())
    }

    mutating func setVerseOfDay() {
        (chapterNumber, verseNumber) = getChapterAndVerseNumber(for: Date())
        currentVerse = getVerse(chapter: chapterNumber, verse: verseNumber)
    }

    private var numberOfChapters: Int {
        VersesInfo.versesPerChapter.count
    }

    func verseOfDayForDate(_ date: Date) -> Verse {
        let (chapterNumber, verseNumber) = getChapterAndVerseNumber(for: date)
        return getVerse(chapter: chapterNumber, verse: verseNumber)
    }
    
    private func getChapterAndVerseNumber(for date: Date) -> (Int, Int) {
        let quoteForDate = quoteReader.quoteOfDayFor(date: date)
        let chapterNumber = quoteForDate.chapterNumber
        let verseNumber = quoteForDate.verseNumber
        return (chapterNumber, verseNumber)
    }
    
    var nextVerse: Verse? {
        if bookmarkedOnlyMode {
            return nextBookmarkedVerse
        }
        else {
            var newVerseNumber = verseNumber + 1
            var newChapterNumber = chapterNumber
            if newVerseNumber > VersesInfo.versesPerChapter[chapterNumber - 1] {
                newChapterNumber += 1
                guard newChapterNumber < numberOfChapters else {
                    return nil
                }
                newVerseNumber = 1
            }
            return getVerse(chapter: newChapterNumber, verse: newVerseNumber)
        }
    }
    
    mutating func setNextVerse(){
        if bookmarkedOnlyMode {
            setNextBookmarkedVerse()
        }
        else {
            var newVerseNumber = verseNumber + 1
            var newChapterNumber = chapterNumber
            if newVerseNumber > VersesInfo.versesPerChapter[chapterNumber - 1] {
                newChapterNumber += 1
                guard newChapterNumber < numberOfChapters else {
                    return
                }
                newVerseNumber = 1
            }
            self.verseNumber = newVerseNumber
            self.chapterNumber = newChapterNumber
            updateVerse(chapter: chapterNumber, verse: verseNumber)
        }
    }
    
    var previousVerse: Verse? {
        if bookmarkedOnlyMode {
            return prevBookmarkedVerse
        }
        else {
            var newVerseNumber = verseNumber - 1
            var newChapterNumber = chapterNumber
            if newVerseNumber < 1 {
                newChapterNumber -= 1
                guard newChapterNumber > 0 else {
                    return nil
                }
                newVerseNumber = VersesInfo.versesPerChapter[newChapterNumber - 1]
            }
            return getVerse(chapter: newChapterNumber, verse: newVerseNumber)
        }
    }
    
    mutating func setPreviousVerse(){
        if bookmarkedOnlyMode {
            getPrevBookmarkedVerse()
        }
        else {
            var newVerseNumber = verseNumber - 1
            var newChapterNumber = chapterNumber
            if newVerseNumber < 1 {
                newChapterNumber -= 1
                guard newChapterNumber > 0 else {
                    return
                }
                newVerseNumber = VersesInfo.versesPerChapter[newChapterNumber - 1]
            }
            self.verseNumber = newVerseNumber
            self.chapterNumber = newChapterNumber
            updateVerse(chapter: chapterNumber, verse: verseNumber)
        }
    }
    
    var nextBookmarkedVerse: Verse {
        verses[bookmarkedVersesModel.nextVerseIndex]
    }

    mutating func setNextBookmarkedVerse() {
        currentVerse = verses[bookmarkedVersesModel.setNextVerseIndex()]
    }
    
    var prevBookmarkedVerse: Verse {
        verses[bookmarkedVersesModel.previousVerseIndex]
    }

    mutating func getPrevBookmarkedVerse() {
        currentVerse = verses[bookmarkedVersesModel.setPrevVerseIndex()]
    }

    mutating func getCurrentBookmarkedVerse() {
        currentVerse = verses[bookmarkedVersesModel.currentBookmarkedVerseIndex]
    }

    mutating func bookmarkCurrentVerse() {
        verses[VersesInfo.getIndexOfVerse(chapter: chapterNumber, verse: verseNumber)].bookmarked = true
        bookmarkedVersesModel.addVerse(chapter: chapterNumber, verse: verseNumber)
        currentVerse.bookmarked = true
    }

    mutating func unbookmarkCurrentVerse() {
        let unbookmarkedIndex = bookmarkedVersesModel.removeCurrentVerse()
        verses[unbookmarkedIndex].bookmarked = false
        currentVerse.bookmarked = false
        checkValidBookmarkOnlyMode()
    }

    mutating func checkNewQuoteOfDay(shownVerseOfDay: Verse) -> Bool {
        if verseOfDay != shownVerseOfDay {
            setVerseOfDay()
            return true
        }
        return false
    }

}


