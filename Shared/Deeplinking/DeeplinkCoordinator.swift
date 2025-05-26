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
        default:
            return .none
        }

    }
}
