import Foundation

struct VersesReader {
    let versesFilePath = Bundle.main.path(forResource: "verses-formatted", ofType: "json")
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verses: [Verse]
    var currentVerse: Verse
    var bookmarkedVersesModel: BookmarkedVersesModel = BookmarkedVersesModel()
    var bookmarkedOnlyMode: Bool = false {
        didSet {
            checkValidBookmarkOnlyMode()
            if bookmarkedOnlyMode {
                getCurrentBookmarkedVerse()
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
        let dayOfYear = Double(Calendar.current.component(.dayOfYear, from: date))
        let weeksPerYear = 52
        let daysPerYear = 366.0
        let numberOfVersesOfDay = Double(VersesInfo.topVerses.count)
        let verseOfDayIndex: Int = Int(((dayOfYear / daysPerYear) * numberOfVersesOfDay).rounded(.toNearestOrAwayFromZero))
        return VersesInfo.topVerses[verseOfDayIndex]
    }
    
    mutating func getNextVerse(){
        if bookmarkedOnlyMode {
            getNextBookmarkedVerse()
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
    
    mutating func getPreviousVerse(){
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

    mutating func getNextBookmarkedVerse() {
        currentVerse = verses[bookmarkedVersesModel.nextVerseIndex()]
    }

    mutating func getPrevBookmarkedVerse() {
        currentVerse = verses[bookmarkedVersesModel.prevVerseIndex()]
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


