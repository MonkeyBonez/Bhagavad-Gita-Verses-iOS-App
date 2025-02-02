import Foundation

struct VersesReader {
    let versesFilePath = Bundle.main.path(forResource: "verses-formatted", ofType: "json")
    var chapterNumber: Int?
    var verseNumber: Int?
    var verses: [Verse]?
    init() {
        guard let versesFilePath = versesFilePath else {
            return
        }
        let fileUrl = URL(fileURLWithPath: versesFilePath)
        guard let data = try? Data(contentsOf: fileUrl) else {
            return
        }
        verses = try? JSONDecoder().decode([Verse].self, from: data)
        (chapterNumber, verseNumber) = getChapterAndVerseNumber(Date())
    }
    
    private func getVerse(chapter: Int, verse: Int) -> Verse? {
        let index = sum(Array(VersesInfo.versesPerChapter.prefix(chapter - 1))) + (verse - 1)
        return verses?[index]
    }
    
    private func sum(_ numbers: [Int]) -> Int {
        numbers.reduce(0, +)
    }
    
    var verseOfDay: Verse? {
        return verseOfDayForDate(Date())
    }
    
    func verseOfDayForDate(_ date: Date) -> Verse? {
        let (chapterNumber, verseNumber) = getChapterAndVerseNumber(date)
        return getVerse(chapter: chapterNumber, verse: verseNumber)
    }
    
    private func getChapterAndVerseNumber(_ date: Date) -> (Int, Int) {
        let dayOfYear = Calendar.current.component(.dayOfYear, from: date)
        let weeksPerYear = 52
        let daysPerYear = 366
        let numberOfVersesOfDay = VersesInfo.topVerses.count //to use
        let verseOfDayIndex: Int = (dayOfYear / (daysPerYear / weeksPerYear)) - 1
        return VersesInfo.topVerses[verseOfDayIndex]
    }
    
    mutating func getNextVerse() -> Verse? { //TO DO check for out of bounds
        guard self.verseNumber != nil, chapterNumber != nil else {
            return nil
        }
        verseNumber! += 1
        if verseNumber! > VersesInfo.versesPerChapter[chapterNumber! - 1] {
            chapterNumber! += 1
            verseNumber! = 1
        }
        return getVerse(chapter: chapterNumber!, verse: verseNumber!)
    }
    
    mutating func getPreviousVerse() -> Verse? { //Same TODO ^
        guard self.verseNumber != nil, chapterNumber != nil else {
            return nil
        }
        verseNumber! -= 1
        if verseNumber! < 1 {
            chapterNumber! -= 1
            verseNumber! = VersesInfo.versesPerChapter[chapterNumber! - 1]
        }
        return getVerse(chapter: chapterNumber!, verse: verseNumber!)
    }
}
