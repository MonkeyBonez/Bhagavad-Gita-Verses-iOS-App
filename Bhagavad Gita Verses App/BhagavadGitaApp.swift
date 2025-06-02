import SwiftUI

@main
struct BhagavadGitaApp: App {
    @Environment(\.openURL) var openURL
    let quoteModel: QuoteModel = QuoteModel()
    let deeplinkCoordinator = DeeplinkCoordinator()

    var body: some Scene {
        WindowGroup {
            QuoteView(dailyQuoteModel: quoteModel)
                .onOpenURL(perform: {handleUrl($0)})
        }
    }

    private func handleUrl(_ url: URL) {
        let action = deeplinkCoordinator.handleDeeplink(url)
        switch action {
        case .none:
            break
        case .quoteOfTheDay:
            setToQuoteOfDay()
        }
    }

    private func setToQuoteOfDay() {
        quoteModel.viewingBookmarkedDisable()
        quoteModel.setToVerseOfDay()
    }
}
