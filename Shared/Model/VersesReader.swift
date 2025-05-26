import Foundation

struct VersesReader {
    let versesFilePath = Bundle.main.path(forResource: "verses-formatted", ofType: "json")
    var chapterNumber: Int
    var verseNumber: Int
    var verses: [Verse]
    init() {
        chapterNumber = 0
        verseNumber = 0
        verses = []
        guard let versesFilePath = versesFilePath else {
            return
        }
        let fileUrl = URL(fileURLWithPath: versesFilePath)
        guard let data = try? Data(contentsOf: fileUrl), let verses = try? JSONDecoder().decode([Verse].self, from: data) else {
            return
        }
        self.verses = verses
        (chapterNumber, verseNumber) = getChapterAndVerseNumber(for: Date())
    }
    
    private func getVerse(chapter: Int, verse: Int) -> Verse? {
        let index = sum(Array(VersesInfo.versesPerChapter.prefix(chapter - 1))) + (verse - 1)
        return verses[index]
    }
    
    private func sum(_ numbers: [Int]) -> Int {
        numbers.reduce(0, +)
    }
    
    private var verseOfDay: Verse? {
        return verseOfDayForDate(Date())
    }

    func getVerseOfDay() -> Verse? {
        return verseOfDay
    }

    mutating func updateWithVerseOfDay() -> Verse? {
        chapterNumber = verseOfDay?.chapterNumber ?? 0
        verseNumber = verseOfDay?.verseNumber ?? 0
        return verseOfDay
    }

    private var numberOfChapters: Int {
        return VersesInfo.versesPerChapter.count
    }

    func verseOfDayForDate(_ date: Date) -> Verse? {
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
    
    mutating func getNextVerse() -> Verse? {
        var newVerseNumber = verseNumber + 1
        var newChapterNumber = chapterNumber
        if newVerseNumber > VersesInfo.versesPerChapter[chapterNumber - 1] {
            newChapterNumber += 1
            guard newChapterNumber < numberOfChapters else {
                return nil
            }
            newVerseNumber = 1
        }
        self.verseNumber = newVerseNumber
        self.chapterNumber = newChapterNumber
        return getVerse(chapter: chapterNumber, verse: verseNumber)
    }
    
    mutating func getPreviousVerse() -> Verse? {
        var newVerseNumber = verseNumber - 1
        var newChapterNumber = chapterNumber
        if newVerseNumber < 1 {
            newChapterNumber -= 1
            guard newChapterNumber > 0 else {
                return nil
            }
            newVerseNumber = VersesInfo.versesPerChapter[newChapterNumber - 1]
        }
        self.verseNumber = newVerseNumber
        self.chapterNumber = newChapterNumber
        return getVerse(chapter: chapterNumber, verse: verseNumber)
    }
}


