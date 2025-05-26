import Foundation
import SwiftUI

@Observable class QuoteModel {
    private var versesReader: VersesReader
    private let currentDate: Date = Date()
    private var userInteracted: Bool = false
    private var shownVerseOfDay: Verse?
    private var lastBackgroundedTime: Date?
    private let backgroundTimeRefreshThresholdHours: Double = 1

    var viewingBookmarked: Bool {
        versesReader.bookmarkedOnlyMode
    }

    var quote: String {
        versesReader.currentVerse.text
    }

    var chapter: Int {
        versesReader.currentVerse.chapterNumber
    }

    var verse: Int {
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
        "\"\(quote)\"\n\(author)\n\(chapter):\(verse)"
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
        versesReader.getPreviousVerse()
    }

    func getNextVerse() {
        userInteracted = true
        versesReader.getNextVerse()
    }

    func bookmarkTapped() {
        bookmarked ? versesReader.unbookmarkCurrentVerse() : versesReader.bookmarkCurrentVerse()
    }

    func viewingBookmarkedTapped() {
//        viewingBookmarked.toggle()
        versesReader.bookmarkedOnlyMode.toggle()
    }

}

// Lock screen widget-specific code
extension QuoteModel {

    func getVerseForDate(_ date: Date) -> Verse? {
        return versesReader.verseOfDayForDate(date)
    }

}

