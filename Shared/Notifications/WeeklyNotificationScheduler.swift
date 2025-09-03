import Foundation
import UserNotifications

enum WeeklyNotificationScheduler {

    private static let scheduledMapKey = "weekly_notif_scheduled_map" // [anchorTs: {id, fireTs}]

    static func onAppOpen(now: Date = Date()) {
        requestAuthorizationIfNeeded { granted in
            guard granted else { return }
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
    }

    private static func scheduleWeeklyReminder(fireAt: Date, anchorTs: Int) {
        let content = UNMutableNotificationContent()
        content.title = "New weekly lesson"
        content.body = "Your new lesson is ready — tap to open"
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
}


