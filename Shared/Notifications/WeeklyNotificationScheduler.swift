import Foundation
import UserNotifications

/// Pure scheduling math for the weekly-lesson notification.
///
/// No UserNotifications, no UserDefaults, no `Date()` — every input is passed in, so this
/// is fully unit-testable. `WeeklyNotificationScheduler` is the thin side-effecting shell
/// that feeds these results to `UNUserNotificationCenter`.
enum WeeklyNotificationPlan {
    /// How many future weekly notifications to keep queued (well under iOS's 64-request cap).
    static let weeksToSchedule = 26
    /// Prefix for the notifications this system schedules. The `regular_` prefix and the
    /// `<Sunday-anchor-epoch-seconds>` suffix are the shipped scheme — do NOT change them, or
    /// existing users' pending notifications stop matching and get needlessly rescheduled.
    static let activeIdPrefix = "regular_"
    /// Every ID namespace this app has ever scheduled. Anything with one of these prefixes is
    /// ours to prune; foreign IDs are left untouched. Includes the retired `streak_` and
    /// `weekly_lesson_reminder_` prefixes so stale ones on existing installs get cleaned up.
    static let managedIdPrefixes = ["regular_", "streak_", "weekly_lesson_reminder_"]

    static let notificationTitle = "New weekly lesson"
    static let notificationBody = "Review your refreshed weekly lesson"

    struct Entry: Equatable {
        let id: String      // "regular_<sundayAnchorTs>"
        let fireDate: Date  // that Sunday, 09:00 local
    }

    /// Sunday-00:00 anchor of the week containing `date`. Same algorithm as
    /// `WeeklyPickSync.sundayStart(for:)`, but with an injectable calendar for testing.
    static func sundayStart(for date: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay) // 1 == Sunday
        let daysSinceSunday = (weekday + 6) % 7
        let thisSunday = calendar.date(byAdding: .day, value: -daysSinceSunday, to: startOfDay) ?? startOfDay
        return calendar.startOfDay(for: thisSunday)
    }

    static func id(forAnchor anchor: Date) -> String {
        "\(activeIdPrefix)\(Int(anchor.timeIntervalSince1970))"
    }

    /// The Sunday-09:00-local fire date for a week anchor (Sunday 00:00). Component-based, so it
    /// stays 09:00 wall-clock across DST transitions.
    static func fireDate(forAnchor anchor: Date, calendar: Calendar = .current) -> Date {
        let comps = calendar.dateComponents([.year, .month, .day], from: anchor)
        var dc = DateComponents()
        dc.year = comps.year
        dc.month = comps.month
        dc.day = comps.day
        dc.hour = 9
        dc.minute = 0
        dc.second = 0
        return calendar.date(from: dc) ?? anchor.addingTimeInterval(9 * 3600)
    }

    /// The `weeks` Sunday-09:00 entries strictly AFTER the current week's anchor.
    /// The current week is deliberately excluded: "suppress if the user already opened the app
    /// this week" then falls out naturally — the current week's ID is never in the desired set,
    /// so pruning removes any pending/delivered notification for it.
    static func desiredEntries(now: Date, weeks: Int = weeksToSchedule, calendar: Calendar = .current) -> [Entry] {
        var entries: [Entry] = []
        var anchor = sundayStart(for: now, calendar: calendar)
        for _ in 0..<weeks {
            guard let next = calendar.date(byAdding: .day, value: 7, to: anchor) else { break }
            anchor = calendar.startOfDay(for: next)
            entries.append(Entry(id: id(forAnchor: anchor), fireDate: fireDate(forAnchor: anchor, calendar: calendar)))
        }
        return entries
    }

    /// "regular_<currentWeekAnchorTs>" — the ID whose delivered banner is cleared on open.
    static func currentWeekId(now: Date, calendar: Calendar = .current) -> String {
        id(forAnchor: sundayStart(for: now, calendar: calendar))
    }

    /// Managed IDs in `pendingIds` that are not in `desiredIds`. Foreign IDs are never returned.
    /// Pass `desiredIds: []` to sweep every managed ID (used for the delivered-banner cleanup).
    static func idsToRemove(pendingIds: [String], desiredIds: Set<String>) -> [String] {
        pendingIds.filter { id in
            guard managedIdPrefixes.contains(where: { id.hasPrefix($0) }) else { return false }
            return !desiredIds.contains(id)
        }
    }
}

/// Schedules exactly one weekly-lesson notification per upcoming week (Sunday 09:00 local),
/// suppressing the current week's once the user opens the app. Idempotent and self-healing:
/// every reconcile prunes stale notifications from earlier schemes and obsolete defaults.
enum WeeklyNotificationScheduler {

    // MARK: - Public entry points

    /// Onboarding "Enable notifications" tap: prompt, then reconcile if granted.
    /// Always invokes `completion` (with `false` on denial) so the onboarding UI can advance.
    static func requestAuthorizationAndReconcile(now: Date = Date(), completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else {
                completion?(false)
                return
            }
            reconcile(now: now) { completion?(true) }
        }
    }

    /// Call on every app open / foreground. Never prompts; no-ops unless already authorized.
    /// Idempotent — safe to call multiple times per session.
    static func reconcileOnAppOpen(now: Date = Date(), completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                reconcile(now: now) { completion?() }
            default:
                completion?()
            }
        }
    }

    // MARK: - Core reconcile

    private static func reconcile(now: Date, completion: @escaping () -> Void) {
        // WeeklyEngagement is the single writer of the opened-week history; recording here is
        // belt-and-suspenders for the notification-authorized path (idempotent set insert).
        WeeklyEngagement.recordCurrentWeekOpen(now: now)
        retireObsoleteDefaults()

        let center = UNUserNotificationCenter.current()
        let desired = WeeklyNotificationPlan.desiredEntries(now: now)
        let desiredIds = Set(desired.map { $0.id })

        center.getPendingNotificationRequests { requests in
            // Prune everything managed that isn't in the desired set: the current week's
            // notification (suppress-on-open), retired streak_/weekly_lesson_reminder_ strays,
            // and any regular_ outside the rolling horizon.
            let toRemove = WeeklyNotificationPlan.idsToRemove(pendingIds: requests.map { $0.identifier }, desiredIds: desiredIds)
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: toRemove)
            }

            // Upsert the desired 26 weekly notifications. Re-adding an existing identifier
            // replaces it, so this is idempotent.
            for entry in desired {
                center.add(makeRequest(for: entry), withCompletionHandler: nil)
            }

            // Clear any already-delivered managed banners (e.g. this week's, now that the app
            // is open) from Notification Center.
            center.getDeliveredNotifications { delivered in
                let deliveredToRemove = WeeklyNotificationPlan.idsToRemove(
                    pendingIds: delivered.map { $0.request.identifier },
                    desiredIds: []
                )
                if !deliveredToRemove.isEmpty {
                    center.removeDeliveredNotifications(withIdentifiers: deliveredToRemove)
                }
                #if DEBUG
                debugDumpPending()
                #endif
                completion()
            }
        }
    }

    private static func makeRequest(for entry: WeeklyNotificationPlan.Entry) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = WeeklyNotificationPlan.notificationTitle
        content.body = WeeklyNotificationPlan.notificationBody
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: entry.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        return UNNotificationRequest(identifier: entry.id, content: content, trigger: trigger)
    }

    // MARK: - Cleanup of superseded state

    /// Remove defaults left behind by earlier notification schemes. Idempotent; runs every
    /// reconcile so every existing install eventually gets cleaned on its next launch.
    private static func retireObsoleteDefaults() {
        SharedDefaults.defaults.removeObject(forKey: DefaultsKeys.weeklyNotifScheduledMap)
        SharedDefaults.defaults.removeObject(forKey: DefaultsKeys.legacyNotifMigratedV2)
    }

    // MARK: - DEBUG

    #if DEBUG
    static func debugDumpPending() {
        let center = UNUserNotificationCenter.current()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        center.getPendingNotificationRequests { requests in
            let managed = requests
                .filter { req in WeeklyNotificationPlan.managedIdPrefixes.contains { req.identifier.hasPrefix($0) } }
                .sorted { a, b in nextFireDate(a) ?? .distantFuture < nextFireDate(b) ?? .distantFuture }
            print("[WeeklyNotif][DEBUG] pending managed count=\(managed.count)")
            for req in managed {
                let when = nextFireDate(req).map { fmt.string(from: $0) } ?? "(unknown)"
                print("[WeeklyNotif][DEBUG]   \(req.identifier) fires=\(when)")
            }
        }
        center.getDeliveredNotifications { delivered in
            let managed = delivered.filter { d in WeeklyNotificationPlan.managedIdPrefixes.contains { d.request.identifier.hasPrefix($0) } }
            print("[WeeklyNotif][DEBUG] delivered managed count=\(managed.count) ids=\(managed.map { $0.request.identifier })")
        }
    }

    private static func nextFireDate(_ req: UNNotificationRequest) -> Date? {
        if let t = req.trigger as? UNCalendarNotificationTrigger { return t.nextTriggerDate() }
        if let t = req.trigger as? UNTimeIntervalNotificationTrigger { return t.nextTriggerDate() }
        return nil
    }
    #endif
}
