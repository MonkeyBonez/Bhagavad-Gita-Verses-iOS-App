import Foundation

/// Migrates data written by pre-App-Group builds (which persisted to `UserDefaults.standard`)
/// into the shared App Group container.
///
/// The original v1 implementation read from `SharedDefaults.defaults` (the App Group) as its
/// source, so it copied the store onto itself and never actually migrated anything — users who
/// upgraded from a pre-App-Group version silently lost bookmarks and history. This v2 pass reads
/// from `UserDefaults.standard` and merges into the App Group without clobbering data the user has
/// accumulated since.
enum AppGroupMigration {

    typealias BookmarkV2 = (index: Int, ts: TimeInterval)

    /// Runs the v2 migration once. Safe to call on every launch; the flag makes it idempotent.
    static func migrateStandardToAppGroupIfNeeded() {
        let group = SharedDefaults.defaults
        if group.bool(forKey: DefaultsKeys.appGroupMigratedV2) { return }
        migrate(from: .standard, to: group)
        group.set(true, forKey: DefaultsKeys.appGroupMigratedV2)
    }

    /// Core migration, parameterized on source/destination stores for testability.
    static func migrate(from source: UserDefaults, to destination: UserDefaults) {
        // Bookmarks: union-merge so neither the migrated nor the newly-accumulated set is lost.
        let mergedV2 = mergeBookmarksV2(
            source: decodeBookmarksV2(source.data(forKey: DefaultsKeys.savedVersesV2)),
            destination: decodeBookmarksV2(destination.data(forKey: DefaultsKeys.savedVersesV2))
        )
        if !mergedV2.isEmpty, let data = encodeBookmarksV2(mergedV2) {
            destination.set(data, forKey: DefaultsKeys.savedVersesV2)
        }

        let mergedLegacy = mergeBookmarkIndices(
            source: source.array(forKey: DefaultsKeys.savedVerses) as? [Int] ?? [],
            destination: destination.array(forKey: DefaultsKeys.savedVerses) as? [Int] ?? []
        )
        if !mergedLegacy.isEmpty {
            destination.set(mergedLegacy, forKey: DefaultsKeys.savedVerses)
        }

        // Everything else: copy only if the App Group has no value yet, so stale standard-defaults
        // data can never overwrite the current shared state.
        copyIfAbsent(key: DefaultsKeys.weeklyShownHistory, from: source, to: destination)
        copyIfAbsent(key: DefaultsKeys.weeklyNotifScheduledMap, from: source, to: destination)
        for (key, value) in source.dictionaryRepresentation()
            where key.hasPrefix(DefaultsKeys.weeklyPickPrefix) && destination.object(forKey: key) == nil {
            destination.set(value, forKey: key)
        }
    }

    // MARK: - Pure merge helpers (unit-tested)

    /// Union of two legacy `[Int]` bookmark lists, sorted ascending.
    static func mergeBookmarkIndices(source: [Int], destination: [Int]) -> [Int] {
        Array(Set(source).union(destination)).sorted()
    }

    /// Union of two V2 bookmark lists keyed by `index`, keeping the earlier timestamp when an
    /// index appears in both. Result is sorted by index.
    static func mergeBookmarksV2(source: [BookmarkV2], destination: [BookmarkV2]) -> [BookmarkV2] {
        var byIndex: [Int: TimeInterval] = [:]
        for e in destination { byIndex[e.index] = e.ts }
        for e in source {
            if let existing = byIndex[e.index] {
                byIndex[e.index] = Swift.min(existing, e.ts)
            } else {
                byIndex[e.index] = e.ts
            }
        }
        return byIndex.keys.sorted().map { (index: $0, ts: byIndex[$0]!) }
    }

    // MARK: - V2 (de)coding

    /// Decodes the `[{index, ts}]` JSON format written by `BookmarkedVersesModel`.
    static func decodeBookmarksV2(_ data: Data?) -> [BookmarkV2] {
        guard let data,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        var out: [BookmarkV2] = []
        for obj in arr {
            if let idx = obj["index"] as? Int {
                let ts = (obj["ts"] as? TimeInterval) ?? 0
                out.append((index: idx, ts: ts))
            }
        }
        return out
    }

    static func encodeBookmarksV2(_ entries: [BookmarkV2]) -> Data? {
        let arr = entries.map { ["index": $0.index, "ts": $0.ts] as [String: Any] }
        return try? JSONSerialization.data(withJSONObject: arr)
    }

    // MARK: - Private

    private static func copyIfAbsent(key: String, from source: UserDefaults, to destination: UserDefaults) {
        guard destination.object(forKey: key) == nil else { return }
        if let value = source.object(forKey: key) {
            destination.set(value, forKey: key)
        }
    }
}
