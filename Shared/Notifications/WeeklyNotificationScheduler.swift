import Foundation
import UserNotifications

enum WeeklyNotificationScheduler {

    private static let scheduledMapKey = "weekly_notif_scheduled_map" // [anchorTs: {id, fireTs}]
    private static let openedWeeksKey = "opened_week_anchors" // [Int]
    private static let backlogWeeksCount = 26

    static func onAppOpen(now: Date = Date()) {
        requestAuthorizationIfNeeded { granted in
            guard granted else { return }
            handleWeeklyLifecycle(now: now)
        }
    }

    // Call this on app open, but only if notifications are already authorized.
    // This will NOT prompt for authorization.
    static func onAppOpenIfAuthorized(now: Date = Date()) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                // DEBUG: Print any pending weekly reminder requests and our saved map
                debugPrintWeeklyPending(now: now)
                handleWeeklyLifecycle(now: now)
            default:
                break
            }
        }
    }

    // Invoke when the user explicitly taps "Enable notifications" during onboarding.
    // Requests permission and, if granted, schedules the first reminder 7 days from now.
    static func userTappedEnableNotifications(now: Date = Date(), completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else {
                completion?(false)
                return
            }
            // Run the new idempotent reconciliation flow.
            ensureBacklogAndStreak(now: now) {
                completion?(true)
            }
        }
    }

    // Internal: manage cancel/reschedule behavior tied to weekly lifecycle without prompting.
    private static func handleWeeklyLifecycle(now: Date) {
        let anchor = WeeklyPickSync.sundayStart(for: now)
        let anchorTs = Int(anchor.timeIntervalSince1970)
        var map = loadScheduledMap()
        if let entry = map[anchorTs] {
            // There is a pending notification for this week's first entry
            // If the user opened the app before it fires, cancel it and clear
            let fireTs = entry["fireTs"] as? TimeInterval ?? 0
            if now.timeIntervalSince1970 < fireTs {
                let id = entry["id"] as? String ?? ""
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
                map.removeValue(forKey: anchorTs)
                saveScheduledMap(map)
            }
            return
        }
        // First open of this week → schedule exactly 1 week from now
        let fireAt = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 3600)
        scheduleWeeklyReminder(fireAt: fireAt, anchorTs: anchorTs)
    }

    private static func scheduleWeeklyReminder(fireAt: Date, anchorTs: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New weekly lesson"
        content.body = "Review your refreshed weekly lesson"
        content.sound = .default

        // Trigger exactly one week from first open time
        let interval = max(1, fireAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let identifier = "weekly_lesson_reminder_\(anchorTs)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                var map = loadScheduledMap()
                map[anchorTs] = [
                    "id": identifier,
                    "fireTs": fireAt.timeIntervalSince1970
                ]
                saveScheduledMap(map)
            }
        }
    }

    private static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    // MARK: - New scheduling model: Sunday 9am backlog + streak, idempotent on app open

    /// Public entrypoint to reconcile notifications on app open or onboarding enable.
    static func ensureBacklogAndStreak(now: Date = Date(), completion: (() -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                migrateLegacyIfNeeded {
                    reconcileBacklogAndStreak(now: now) {
                        completion?()
                    }
                }
            default:
                completion?()
            }
        }
    }

    /// Reconcile based on current time and opened-week tracking. Idempotent.
    private static func reconcileBacklogAndStreak(now: Date, completion: @escaping () -> Void) {
        let currentAnchor = WeeklyPickSync.sundayStart(for: now)
        let nextAnchor = WeeklyPickSync.nextSundayStart(after: now)
        let currentTs = Int(currentAnchor.timeIntervalSince1970)
        let nextTs = Int(nextAnchor.timeIntervalSince1970)

        // Mark this week as opened (first open this week or subsequent opens)
        markWeekOpened(anchorTs: currentTs)

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            // Cancel any current-week notifications (regular or streak)
            let currentRegularId = "regular_\(currentTs)"
            let currentStreakId = "streak_\(currentTs)"
            center.removePendingNotificationRequests(withIdentifiers: [currentRegularId, currentStreakId])

            // Cancel next week's regular. We'll replace with streak.
            let nextRegularId = "regular_\(nextTs)"
            center.removePendingNotificationRequests(withIdentifiers: [nextRegularId])

            // Upsert streak for next week at openTs + 7d
            let nextStreakId = "streak_\(nextTs)"
            center.removePendingNotificationRequests(withIdentifiers: [nextStreakId])
            let streakFireAt = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 3600)
            scheduleStreak(fireAt: streakFireAt, nextAnchorTs: nextTs)

            // Top up backlog: future Sundays at 9:00 AM, skipping next week (occupied by streak)
            let futureAnchors = futureSundayAnchors(startingAfter: nextAnchor, count: backlogWeeksCount)
            for anchor in futureAnchors {
                let ts = Int(anchor.timeIntervalSince1970)
                let id = "regular_\(ts)"
                let fireAt = sundayAt9am(forWeekAnchor: anchor)
                scheduleRegularIfNeeded(id: id, fireAt: fireAt)
            }

            // Prune: remove any of our regular_* that are not in the allowed future set or are <= nextAnchor (we canceled those above), and trim excess if any.
            let allowedRegularIds: Set<String> = Set(futureAnchors.map { "regular_\(Int($0.timeIntervalSince1970))" })
            let ourRequests = requests.filter { $0.identifier.hasPrefix("regular_") || $0.identifier.hasPrefix("streak_") }
            var toRemove: [String] = []
            for req in ourRequests {
                if req.identifier.hasPrefix("regular_") && !allowedRegularIds.contains(req.identifier) {
                    toRemove.append(req.identifier)
                }
                // Remove any current/next week remnants that might have been queued outside this pass
                if req.identifier == currentRegularId || req.identifier == currentStreakId || req.identifier == nextRegularId { toRemove.append(req.identifier) }
            }
            if !toRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: Array(Set(toRemove)))
            }

            completion()
        }
    }

    // MARK: - Helpers

    /// Compute Date for Sunday 9:00 AM local for a given week anchor (which is Sunday 00:00 local).
    private static func sundayAt9am(forWeekAnchor anchor: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: anchor)
        var dc = DateComponents()
        dc.year = comps.year
        dc.month = comps.month
        dc.day = comps.day
        dc.hour = 9
        dc.minute = 0
        dc.second = 0
        return cal.date(from: dc) ?? anchor.addingTimeInterval(9 * 3600)
    }

    /// Generate `count` future Sunday anchors strictly after the provided anchor, spaced 1 week apart.
    private static func futureSundayAnchors(startingAfter anchor: Date, count: Int) -> [Date] {
        var out: [Date] = []
        var cur = anchor
        let cal = Calendar.current
        for _ in 0..<count {
            guard let next = cal.date(byAdding: .day, value: 7, to: cur) else { break }
            out.append(cal.startOfDay(for: next))
            cur = next
        }
        return out
    }

    /// Schedule regular notification (Sunday 9am) if not already scheduled with same identifier. Re-adding with same identifier is idempotent.
    private static func scheduleRegularIfNeeded(id: String, fireAt: Date) {
        let content = UNMutableNotificationContent()
        content.title = "New weekly lesson"
        content.body = "Review your refreshed weekly lesson"
        content.sound = .default
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Schedule streak notification for next week at the specified time.
    private static func scheduleStreak(fireAt: Date, nextAnchorTs: Int) {
        let streak = computeStreak(now: Date())
        let content = UNMutableNotificationContent()
        content.title = "New weekly lesson"
        if streak <= 1 {
            content.body = "Start a weekly lesson study streak"
        } else {
            content.body = "Keep up your \(streak) week lesson study streak"
        }
        content.sound = .default
        let interval = max(1, fireAt.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let id = "streak_\(nextAnchorTs)"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// Compute consecutive opened-week count ending at the current week.
    private static func computeStreak(now: Date) -> Int {
        let cal = Calendar.current
        let currentAnchor = WeeklyPickSync.sundayStart(for: now)
        let opened = loadOpenedWeeks()
        var count = 0
        var anchor = currentAnchor
        while opened.contains(Int(anchor.timeIntervalSince1970)) {
            count += 1
            if let prev = cal.date(byAdding: .day, value: -7, to: anchor) {
                anchor = prev
            } else {
                break
            }
        }
        return max(count, 1)
    }

    /// Persist that a specific week (anchorTs) was opened at least once.
    private static func markWeekOpened(anchorTs: Int) {
        var set = loadOpenedWeeks()
        set.insert(anchorTs)
        saveOpenedWeeks(set)
    }

    private static func loadOpenedWeeks() -> Set<Int> {
        if let arr = SharedDefaults.defaults.array(forKey: openedWeeksKey) as? [Int] {
            return Set(arr)
        }
        return []
    }

    private static func saveOpenedWeeks(_ set: Set<Int>) {
        SharedDefaults.defaults.set(Array(set), forKey: openedWeeksKey)
    }

    /// Cancel legacy identifiers and clear old map once.
    private static func migrateLegacyIfNeeded(completion: @escaping () -> Void) {
        let didMigrateKey = "notif_migrated_v2"
        if SharedDefaults.defaults.bool(forKey: didMigrateKey) {
            completion(); return
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let legacyIds = requests.filter { $0.identifier.hasPrefix("weekly_lesson_reminder_") }.map { $0.identifier }
            if !legacyIds.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: legacyIds)
            }
            // Clear old map used by legacy scheduler
            SharedDefaults.defaults.removeObject(forKey: scheduledMapKey)
            SharedDefaults.defaults.set(true, forKey: didMigrateKey)
            completion()
        }
    }

    private static func loadScheduledMap() -> [Int: [String: Any]] {
        if let data = SharedDefaults.defaults.data(forKey: scheduledMapKey),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            var out: [Int: [String: Any]] = [:]
            for (k, v) in obj { if let ik = Int(k) { out[ik] = v } }
            return out
        }
        return [:]
    }

    private static func saveScheduledMap(_ map: [Int: [String: Any]]) {
        var obj: [String: [String: Any]] = [:]
        for (k, v) in map { obj[String(k)] = v }
        if let data = try? JSONSerialization.data(withJSONObject: obj) {
            SharedDefaults.defaults.set(data, forKey: scheduledMapKey)
        }
    }

    // MARK: - DEBUG helpers
    private static func debugPrintWeeklyPending(now: Date) {
        #if DEBUG
        let anchor = WeeklyPickSync.sundayStart(for: now)
        let anchorTs = Int(anchor.timeIntervalSince1970)
        let map = loadScheduledMap()
        print("[WeeklyNotificationScheduler][DEBUG] Current week anchorTs=\(anchorTs)")
        if let entry = map[anchorTs] {
            print("[WeeklyNotificationScheduler][DEBUG] Saved scheduledMap entry for this week: id=\(entry["id"] ?? "") fireTs=\(entry["fireTs"] ?? 0)")
        } else {
            print("[WeeklyNotificationScheduler][DEBUG] No saved scheduledMap entry for this week")
        }
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let weekly = requests.filter { $0.identifier.hasPrefix("weekly_lesson_reminder_") }
            print("[WeeklyNotificationScheduler][DEBUG] Pending weekly requests count=\(weekly.count)")
            for req in weekly {
                var triggerInfo = ""
                if let trig = req.trigger as? UNTimeIntervalNotificationTrigger {
                    triggerInfo = "timeInterval=\(trig.timeInterval) repeats=\(trig.repeats)"
                } else if let dc = req.trigger as? UNCalendarNotificationTrigger {
                    triggerInfo = "calendarTrigger dateComponents=\(dc.dateComponents) repeats=\(dc.repeats)"
                } else {
                    triggerInfo = String(describing: type(of: req.trigger))
                }
                print("[WeeklyNotificationScheduler][DEBUG] id=\(req.identifier) title=\(req.content.title) body=\(req.content.body) trigger=\(triggerInfo)")
            }
        }
        #endif
    }

}


