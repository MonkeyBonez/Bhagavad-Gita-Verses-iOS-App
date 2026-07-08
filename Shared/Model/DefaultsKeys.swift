import Foundation

/// Centralized UserDefaults key strings shared across the app, widgets, and app intent extensions.
///
/// The string values must remain byte-identical to previously shipped versions — changing one
/// orphans existing user data. Add new keys here rather than inlining literals at call sites.
public enum DefaultsKeys {
    /// Legacy bookmark storage: `[Int]` of global verse indices.
    public static let savedVerses = "SavedVerses"
    /// Current bookmark storage: JSON `[{index, ts}]`.
    public static let savedVersesV2 = "SavedVersesV2"
    /// Weekly "already shown" history: JSON `[{index, ts}]`.
    public static let weeklyShownHistory = "weekly_shown_history"
    /// Prefix for per-week pick keys (`weekly_pick_<anchorTs>`).
    public static let weeklyPickPrefix = "weekly_pick_"
    /// Weekly notification scheduling map: JSON `{anchorTs: {id, fireTs}}`.
    public static let weeklyNotifScheduledMap = "weekly_notif_scheduled_map"
    /// Whether onboarding has been completed.
    public static let onboardingCompleted = "onboarding_completed_v1"
    /// Timestamp of the last widget-timeline refresh anchor.
    public static let lastWidgetRefreshAnchorTs = "last_widget_refresh_anchor_ts"
    /// One-shot flag for the (broken, superseded) v1 App Group migration.
    public static let appGroupMigratedV1 = "app_group_migrated_v1_debug"
    /// One-shot flag for the corrected v2 App Group migration.
    public static let appGroupMigratedV2 = "app_group_migrated_v2"
}
