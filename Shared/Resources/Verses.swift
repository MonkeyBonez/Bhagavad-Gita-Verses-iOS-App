struct Verse: Codable {
    let verse: String
    let chapterNumber: Int
    let verseNumber: Int
}

extension Verse: Equatable {
    static func == (lhs: Verse, rhs: Verse) -> Bool {
        return lhs.verseNumber == rhs.verseNumber && lhs.chapterNumber == rhs.chapterNumber
    }
}
