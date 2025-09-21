import Foundation

enum AppGroupMigration {

    private static let migrationFlagKey = "app_group_migrated_v1_debug"

    static func migrateStandardToAppGroupIfNeeded() {
        // Only run once
        if SharedDefaults.defaults.bool(forKey: migrationFlagKey) {
            return
        }

        let std = SharedDefaults.defaults
        let stdDict = std.dictionaryRepresentation()

        // 1) Weekly picks (old versions saved under standard defaults)
        for (key, value) in stdDict where key.hasPrefix("weekly_pick_") {
            SharedDefaults.defaults.set(value, forKey: key)
        }

        // 2) Weekly shown history
        if let shown = std.data(forKey: "weekly_shown_history") {
            SharedDefaults.defaults.set(shown, forKey: "weekly_shown_history")
        }

        // 3) Bookmarks (legacy + V2)
        if let bookmarksV2 = std.data(forKey: "SavedVersesV2") {
            SharedDefaults.defaults.set(bookmarksV2, forKey: "SavedVersesV2")
        }
        if let bookmarksLegacy = std.array(forKey: "SavedVerses") as? [Int] {
            SharedDefaults.defaults.set(bookmarksLegacy, forKey: "SavedVerses")
        }

        // 4) Weekly notifications map (if present)
        if let notifMap = std.data(forKey: "weekly_notif_scheduled_map") {
            SharedDefaults.defaults.set(notifMap, forKey: "weekly_notif_scheduled_map")
        }

        SharedDefaults.defaults.set(true, forKey: migrationFlagKey)
    }
}



