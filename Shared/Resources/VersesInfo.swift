struct VersesInfo {
    static let author = "Bhagavad Gita"
    static let versesPerChapter = [47,72,43,42,29,47,30,28,34,42,55,20,35,27,20,24,28,78]
    static let topVerses = [(2, 47), (2, 56), (2, 71), (3, 9), (3, 19), (4, 10), (4, 18), (4, 19), (5, 24), (5, 29), (6, 5), (6, 21), (6, 32), (9, 27), (9, 29), (9, 34), (12, 13), (12, 16), (12, 17), (14, 26), (18, 46), (18, 53), (18, 55), (18, 57), (18, 65), (18, 66)]
    static func getIndexOfVerse(chapter: Int, verse: Int) -> Int {
        sum(Array(versesPerChapter.prefix(chapter - 1))) + (verse - 1)
    }
    static private func sum(_ numbers: [Int]) -> Int {
        numbers.reduce(0, +)
    }
}
