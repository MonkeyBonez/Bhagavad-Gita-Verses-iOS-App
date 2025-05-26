import Foundation
import SwiftUI

@Observable class QuoteModel {
    private var versesReader: VersesReader
    private let currentDate: Date = Date()
    private var userInteracted: Bool = false
    
    var quote: String
    
    var chapter: String
    
    var verse: String
    
    var author: String
    
    init() {
        let versesReader = VersesReader()
        self.versesReader = versesReader
        guard let verseOfDay = versesReader.verseOfDay else {
            self.quote = ""
            self.chapter = ""
            self.verse = ""
            self.author = ""
            //better exit failure - throw error?
            return
        }
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
    
    private func getDaysIndex() -> Int {
        Calendar.current.component(.day, from: forDate) - 1
    }
    
    private func updateInfo() {
        guard let verseOfDay = versesReader.verseOfDayForDate(forDate) else {
            return
        }
        self.quote = verseOfDay.verse
        self.chapter = String(verseOfDay.chapterNumber)
        self.verse = String(verseOfDay.verseNumber)
        self.author = VersesInfo.author
    }
    
    private var forDate: Date = Date() {
        didSet {
            updateInfo()
        }
    }
    
    func viewLoaded() {
        if !userInteracted {
            setDate(Date())
        }
    }
    
    func setDate(_ date: Date){
        forDate = date
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
    
    private func updateWithVerse(_ verse: Verse) {
        self.quote = verse.verse
        self.chapter = String(verse.chapterNumber)
        self.verse = String(verse.verseNumber)
        self.author = VersesInfo.author
    }
}
