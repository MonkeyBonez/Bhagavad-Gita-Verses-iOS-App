import Foundation
struct DeeplinkScheme {
    static let app = "bhagavadgitaverses"
    static func createDeeplink(path: DeeplinkPaths?) -> URL {
        return URL(string: "\(app)://bhagavadgitaverses/\(path ?? .empty)")!
    }
}

enum DeeplinkPaths: String, CaseIterable {
    case empty = ""
    case lockScreenWidget = "lockScreenWidget"
    case verseOfDayIntent = "verseOfDayIntent"
    case homeScreenWidget = "homeScreenWidget"
    case verse = "verse" // e.g., bhagavadgitaverses://bhagavadgitaverses/verse?chapter=2&verse=47
}

enum DeeplinkActions {
    case none
    case quoteOfTheDay
    case openVerse(chapter: Int, verse: Int)
}
