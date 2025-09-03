import SwiftUI
import UserNotifications

@main
struct BhagavadGitaApp: App {
    @Environment(\.openURL) var openURL
    let quoteModel: QuoteModel = QuoteModel()
    let deeplinkCoordinator = DeeplinkCoordinator()

    var body: some Scene {
        WindowGroup {
            VerseView(dailyQuoteModel: quoteModel)
                .onOpenURL(perform: {handleUrl($0)})
                .onAppear { WeeklyNotificationScheduler.onAppOpen() }
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
