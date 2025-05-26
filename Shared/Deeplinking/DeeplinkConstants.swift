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
}

enum DeeplinkActions {
    case none
    case quoteOfTheDay
}
