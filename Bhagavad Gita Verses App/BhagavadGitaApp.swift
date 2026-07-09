import SwiftUI
import WidgetKit
import UserNotifications

@main
struct BhagavadGitaApp: App {
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
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
                .onAppear { handleForegroundTick() }
                .onChange(of: scenePhase) { _, newPhase in
                    // Cover warm foregrounds: .onAppear fires once per view lifetime, so a
                    // resident app crossing into a new week would otherwise never record it.
                    if newPhase == .active { handleForegroundTick() }
                }
        }
    }

    /// Idempotent per-foreground work: record this week's engagement (independent of notification
    /// permission), reconcile the notification queue, and refresh widgets on a new week.
    private func handleForegroundTick() {
        WeeklyEngagement.recordCurrentWeekOpen()
        WeeklyNotificationScheduler.reconcileOnAppOpen()
        refreshWidgetsIfNewWeek()
    }

    private func handleUrl(_ url: URL) {
        let action = deeplinkCoordinator.handleDeeplink(url)
        switch action {
        case .none:
            break
        case .quoteOfTheDay:
            setToQuoteOfDay()
            WeeklyNotificationScheduler.reconcileOnAppOpen()
        case .openVerse(let chapter, let verse):
            openSpecificVerse(chapter: chapter, verse: verse)
            WeeklyNotificationScheduler.reconcileOnAppOpen()
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
        let key = DefaultsKeys.lastWidgetRefreshAnchorTs
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
    @State private var showOnboarding: Bool = !SharedDefaults.defaults.bool(forKey: DefaultsKeys.onboardingCompleted)
    var body: some View {
        VerseView(dailyQuoteModel: quoteModel, isExternalCoverPresented: $showOnboarding)
            .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
                // Reconcile after onboarding (no-op if notifications weren't enabled)
                WeeklyNotificationScheduler.reconcileOnAppOpen()
            }) {
                OnboardingView()
            }
    }
}
