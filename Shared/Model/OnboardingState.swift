import Foundation

enum OnboardingState {
    private static let completedKey = DefaultsKeys.onboardingCompleted

    static var hasCompleted: Bool {
        SharedDefaults.defaults.bool(forKey: completedKey)
    }

    static func markCompleted() {
        SharedDefaults.defaults.set(true, forKey: completedKey)
    }
}


