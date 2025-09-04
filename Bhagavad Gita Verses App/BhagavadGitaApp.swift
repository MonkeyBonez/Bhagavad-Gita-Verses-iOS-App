import SwiftUI
import UserNotifications

@main
struct BhagavadGitaApp: App {
    @Environment(\.openURL) var openURL
    let quoteModel: QuoteModel = QuoteModel()
    let deeplinkCoordinator = DeeplinkCoordinator()

    var body: some Scene {
        WindowGroup {
            RootContent(quoteModel: quoteModel)
                .onOpenURL(perform: {handleUrl($0)})
                .onAppear { WeeklyNotificationScheduler.onAppOpenIfAuthorized() }
        }
    }

    private func handleUrl(_ url: URL) {
        let action = deeplinkCoordinator.handleDeeplink(url)
        switch action {
        case .none:
            break
        case .quoteOfTheDay:
            setToQuoteOfDay()
            WeeklyNotificationScheduler.onAppOpen()
        case .openVerse(let chapter, let verse):
            openSpecificVerse(chapter: chapter, verse: verse)
            WeeklyNotificationScheduler.onAppOpen()
        }
    }

    private func setToQuoteOfDay() {
        quoteModel.viewingBookmarkedDisable()
        quoteModel.setToVerseOfDay()
    }

    private func openSpecificVerse(chapter: Int, verse: Int) {
        quoteModel.viewingBookmarkedDisable()
        quoteModel.setToChapterVerse(chapter: chapter, verse: verse)
    }
}

// MARK: - RootContent with onboarding gate
private struct RootContent: View {
    @State var quoteModel: QuoteModel
    @State private var showOnboarding: Bool = !SharedDefaults.defaults.bool(forKey: "onboarding_completed_v1")
    var body: some View {
        VerseView(dailyQuoteModel: quoteModel, isExternalCoverPresented: $showOnboarding)
            .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
                // After onboarding, run weekly lifecycle once (authorized only)
                WeeklyNotificationScheduler.onAppOpenIfAuthorized()
            }) {
                OnboardingView()
            }
    }
}
