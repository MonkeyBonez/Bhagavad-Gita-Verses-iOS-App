import SwiftUI
import WidgetKit
import UserNotifications

@main
struct BhagavadGitaApp: App {
    @Environment(\.openURL) var openURL
    let quoteModel: QuoteModel
    let deeplinkCoordinator = DeeplinkCoordinator()

    init() {
        // 1) Move data from standard defaults → App Group so widgets can see it on first run
        AppGroupMigration.migrateStandardToAppGroupIfNeeded()
        // 2) Ensure legacy weekly pick is migrated BEFORE any consumers compute/read the pick
        WeeklyPickSync.migrateLegacyAnchorIfNeeded()
        self.quoteModel = QuoteModel()
    }

    var body: some Scene {
        WindowGroup {
            RootContent(quoteModel: quoteModel)
                .onOpenURL(perform: {handleUrl($0)})
                .onAppear {
                    WeeklyNotificationScheduler.ensureBacklogAndStreak()
                    refreshWidgetsIfNewWeek()
                }
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

    // MARK: - Safety: reload widgets on first app open after midnight
    private func refreshWidgetsIfNewWeek(now: Date = Date()) {
        let anchor = WeeklyPickSync.sundayStart(for: now)
        let key = "last_widget_refresh_anchor_ts"
        let lastTs = SharedDefaults.defaults.double(forKey: key)
        let anchorTs = anchor.timeIntervalSince1970
        if lastTs < anchorTs {
            WidgetCenter.shared.reloadAllTimelines()
            SharedDefaults.defaults.set(anchorTs, forKey: key)
        }
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
