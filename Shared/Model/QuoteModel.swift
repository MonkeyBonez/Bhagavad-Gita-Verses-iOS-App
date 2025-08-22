import Foundation
import SwiftUI

@Observable class QuoteModel {
    private var versesReader: VersesReader
    private let currentDate: Date = Date()
    private var userInteracted: Bool = false
    private var shownVerseOfDay: Verse?
    private var lastBackgroundedTime: Date?
    private let backgroundTimeRefreshThresholdHours: Double = 1

    var viewBookmarkAddIndicator: Bool = false

    var viewingBookmarked: Bool {
        versesReader.bookmarkedOnlyMode
    }

    var quote: Verse {
        versesReader.currentVerse
    }
    
    var prevQuote: Verse? {
        versesReader.previousVerse
    }
    
    var nextQuote: Verse? {
        versesReader.nextVerse
    }

    // MARK: - Paging helpers
    var totalVerseCount: Int {
        versesReader.totalVerseCount
    }

    var currentGlobalIndex: Int {
        versesReader.currentGlobalIndex
    }

    var bookmarkedGlobalIndices: [Int] {
        versesReader.bookmarkedGlobalIndices
    }

    func setCurrentByGlobalIndex(_ index: Int) {
        versesReader.setCurrentByGlobalIndex(index)
    }

    func verse(atGlobalIndex index: Int) -> Verse {
        versesReader.verse(atGlobalIndex: index)
    }

    private var chapter: Int {
        versesReader.currentVerse.chapterNumber
    }

    private var verse: Int {
        versesReader.currentVerse.verseNumber
    }

    var author: String {
        VersesInfo.author
    }

    var bookmarked: Bool {
        versesReader.currentVerse.bookmarked
    }

    init() {
        self.versesReader = VersesReader()
        versesReader.setVerseOfDay()
        self.shownVerseOfDay = versesReader.currentVerse
    }
    
    init(quote: String, author: String, chapter: Int, verse: Int, bookmarked: Bool = false) {
        self.versesReader = VersesReader(currentVerse: Verse(text: quote, chapterNumber: chapter, verseNumber: verse, bookmarked: bookmarked))
    }
    
    func setToVerseOfDay() {
        versesReader.setVerseOfDay()
    }


}

// Main app-specific code
extension QuoteModel {

    private var thresholdInSeconds: Double {
        backgroundTimeRefreshThresholdHours * 60.0 * 60.0
    }

    var shareText: String {
        "\"\(quote.text)\"\n\(author)\n\(chapter):\(verse)"
    }

    var hasBookmarks: Bool {
        versesReader.hasBookmarks
    }

    func scenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .background {
            lastBackgroundedTime = Date()
            versesReader.bookmarkedVersesModel.persistData()
        }
        else if newPhase == .inactive && oldPhase == .background {
            if !versesReader.checkNewQuoteOfDay(shownVerseOfDay: shownVerseOfDay!) {
                checkResetToQuoteOfDay()
            }
        }
    }

    private func checkResetToQuoteOfDay() {
        if let lastBackgroundedTime = lastBackgroundedTime,
           lastBackgroundedTime.timeIntervalSinceNow.isLess(than: -thresholdInSeconds){
            setToVerseOfDay()
        }
    }

    func getPreviousVerse() {
        userInteracted = true
        versesReader.setPreviousVerse()
    }

    func getNextVerse() {
        userInteracted = true
        versesReader.setNextVerse()
    }

    func bookmarkTapped() {
        if bookmarked {
            versesReader.unbookmarkCurrentVerse()
        }
        else {
            versesReader.bookmarkCurrentVerse()
            viewBookmarkAddIndicator.toggle()
        }
    }

    func viewingBookmarkedTapped() {
        versesReader.bookmarkedOnlyMode.toggle()
    }

    func viewingBookmarkedDisable() {
        versesReader.bookmarkedOnlyMode = false
    }

    var bookmarkedOnlyMode: Bool { versesReader.bookmarkedOnlyMode }

}

// widget-specific code
extension QuoteModel {

    func getVerseForDate(_ date: Date) -> Verse? {
        return versesReader.verseOfDayForDate(date)
    }

}

