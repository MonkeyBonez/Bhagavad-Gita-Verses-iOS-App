import Foundation
struct DeeplinkCoordinator {

    func handleDeeplink(_ url: URL) -> DeeplinkActions {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                let scheme = components.scheme, scheme == DeeplinkScheme.app,
              let host = components.host, host == DeeplinkScheme.app
        else {
            return .none
        }
        var trimmingCharacterSet = CharacterSet.whitespacesAndNewlines
        trimmingCharacterSet.insert(charactersIn: "/")
        guard let path = DeeplinkPaths(rawValue: components.path.trimmingCharacters(in: trimmingCharacterSet)) else {
            return .none
        }
        switch path {
        case .lockScreenWidget:
            return .quoteOfTheDay
        case .homeScreenWidget:
            return .quoteOfTheDay
        case .verseOfDayIntent:
            return .quoteOfTheDay
        case .verse:
            if let queryItems = components.queryItems {
                let ch = queryItems.first(where: { $0.name == "chapter" })?.value
                let vs = queryItems.first(where: { $0.name == "verse" })?.value
                if let ch = ch, let vs = vs, let chapter = Int(ch), let verse = Int(vs) {
                    return .openVerse(chapter: chapter, verse: verse)
                }
            }
            return .none
        default:
            return .none
        }

    }
}
