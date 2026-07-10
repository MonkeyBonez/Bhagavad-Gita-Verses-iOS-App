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
    /// Obsolete legacy notification map. No longer written; the notification reconcile
    /// actively deletes it. Kept so the cleanup call can target the exact key string.
    public static let weeklyNotifScheduledMap = "weekly_notif_scheduled_map"
    /// Sunday anchors (epoch seconds) of weeks the app was opened at least once.
    /// Engagement history, kept for future progress/streak features. Stored as `[Int]`.
    public static let openedWeekAnchors = "opened_week_anchors"
    /// Obsolete one-shot flag from the superseded v2 notification migration.
    /// Actively deleted during notification reconcile; kept so cleanup targets the exact key.
    public static let legacyNotifMigratedV2 = "notif_migrated_v2"
    /// Whether onboarding has been completed.
    public static let onboardingCompleted = "onboarding_completed_v1"
    /// Timestamp of the last widget-timeline refresh anchor.
    public static let lastWidgetRefreshAnchorTs = "last_widget_refresh_anchor_ts"
    /// One-shot flag for the (broken, superseded) v1 App Group migration.
    public static let appGroupMigratedV1 = "app_group_migrated_v1_debug"
    /// One-shot flag for the corrected v2 App Group migration.
    public static let appGroupMigratedV2 = "app_group_migrated_v2"
    /// Developer override forcing the on-device explanation backend, for on-device A/B
    /// testing. Values: "fm" | "3b" | "1.5b" | "stub". Absent = automatic device tiering
    /// (`ExplainerTier.recommended`). Not surfaced in UI; set via a debug affordance.
    public static let explainerBackendOverride = "explainer_backend_override"
    /// Prompt framing for the explanation surface. Values: "lesson" (lesson-first — the
    /// lesson is the subject, verse only its source) | "verse" (verse-first — explains the
    /// scene). Absent = lesson-first. Toggled via the debug menu for on-device comparison.
    public static let explainerPromptStyle = "explainer_prompt_style"
}
