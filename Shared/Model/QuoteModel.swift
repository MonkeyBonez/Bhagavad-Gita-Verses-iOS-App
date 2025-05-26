import Foundation
import SwiftUI

@Observable class QuoteModel {
    private var versesReader: VersesReader
    private let currentDate: Date = Date()
    private var userInteracted: Bool = false
    private var shownVerseOfDay: Verse?
    private var lastBackgroundedTime: Date?
    private let backgroundTimeRefreshThresholdHours: Double = 1

    var quote: String
    
    var chapter: String
    
    var verse: String
    
    var author: String
    
    init() {
        let versesReader = VersesReader()
        self.versesReader = versesReader
        guard let verseOfDay = versesReader.getVerseOfDay() else {
            self.quote = ""
            self.chapter = ""
            self.verse = ""
            self.author = ""
            //better exit failure - throw error?
            return
        }
        self.shownVerseOfDay = verseOfDay
        self.quote = verseOfDay.verse
        self.chapter = String(verseOfDay.chapterNumber)
        self.verse = String(verseOfDay.verseNumber)
        self.author = VersesInfo.author
    }
    
    init(quote: String, author: String, chapter: String, verse: String) {
        self.versesReader = VersesReader()
        self.quote = quote
        self.chapter = chapter
        self.verse = verse
        self.author = author
    }
    
    func setToVerseOfDay() {
        guard let verseOfDay = versesReader.updateWithVerseOfDay() else {
            return
        }
        self.shownVerseOfDay = verseOfDay
        updateWithVerse(verseOfDay)
    }

    private func updateWithVerse(_ verse: Verse) {
        self.quote = verse.verse
        self.chapter = String(verse.chapterNumber)
        self.verse = String(verse.verseNumber)
        self.author = VersesInfo.author
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
        }
        else if newPhase == .inactive && oldPhase == .background {
            if !checkNewQuoteOfDay() {
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

    private func checkNewQuoteOfDay() -> Bool {
        if versesReader.getVerseOfDay() != shownVerseOfDay {
            setToVerseOfDay()
            return true
        }
        return false
    }

    func getPreviousVerse() {
        userInteracted = true
        guard let prevVerse = versesReader.getPreviousVerse() else {
            return
        }
        updateWithVerse(prevVerse)
    }

    func getNextVerse() {
        userInteracted = true
        guard let nextVerse = versesReader.getNextVerse() else {
            return
        }
        updateWithVerse(nextVerse)
    }

}

// Lock screen widget-specific code
extension QuoteModel {

    func getVerseForDate(_ date: Date) -> Verse? {
        return versesReader.verseOfDayForDate(date)
    }

}

