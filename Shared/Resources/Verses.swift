struct Verse: Codable {
    let text: String
    let chapterNumber: Int
    let verseNumber: Int
    var bookmarked: Bool = false

    private enum CodingKeys: String, CodingKey {
        case text
        case chapterNumber
        case verseNumber
    }
}

extension Verse: Equatable {
    static func == (lhs: Verse, rhs: Verse) -> Bool {
        return lhs.verseNumber == rhs.verseNumber && lhs.chapterNumber == rhs.chapterNumber
    }
}
