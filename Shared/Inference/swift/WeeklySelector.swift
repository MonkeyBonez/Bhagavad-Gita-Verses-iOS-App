import Foundation

// Shared App Group defaults for cross-process consistency (App + Widgets)
public enum SharedDefaults {
    // Update to your actual App Group identifier configured in entitlements
    private static let suiteName = "group.sattva"
    public static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

public struct WeeklyPick {
    public let lessonIndex: Int
    public let lessonText: String
    public let chapter: Int
    public let verse: Int
}

public protocol WeeklyHeuristic {
    func pick(for date: Date) -> WeeklyPick
}

public struct WeeklyParams {
    public var minCos: Float = 0.30
    public var maxSimilar: Float = 0.88
    public var bandLowPct: Float = 70
    public var bandHighPct: Float = 90
    public var topMPerCluster: Int = 200
    public var noRepeatDays: Int = 180
    public init() {}
}

public final class SattvaWeeklyHeuristic: WeeklyHeuristic {
    private let embeddings: LessonEmbeddingIndex?
    private let unitsIndex: LessonUnitsIndex?
    private let textsIndex: LessonTextsIndex?
    private let verseMap: [String:Int]
    private let params: WeeklyParams
    private let shownKey = "weekly_shown_history"

    public init(params: WeeklyParams = WeeklyParams(), verseToLessonJSON: URL? = nil) {
        self.embeddings = LessonEmbeddingIndex()
        self.unitsIndex = LessonUnitsIndex()
        self.textsIndex = LessonTextsIndex()
        // Load verse_to_lesson.json if provided
        if let url = verseToLessonJSON, let data = try? Data(contentsOf: url), let map = try? JSONSerialization.jsonObject(with: data) as? [String:Int] {
            self.verseMap = map
        } else {
            self.verseMap = [:]
        }
        self.params = params
    }

    public func pick(for date: Date) -> WeeklyPick {
        guard let emb = embeddings, let ui = unitsIndex, let lt = textsIndex, emb.count > 0, ui.count > 0, lt.count > 0 else {
            return FallbackWeeklyHeuristic().pick(for: date)
        }
        // 1) Collect seeds from bookmarks
        let seeds = loadSeedLessonIndices()
        if seeds.isEmpty {
            return FallbackWeeklyHeuristic().pick(for: date)
        }
        // 2) Compute k
        let k = max(1, min(3, Int((Float(seeds.count)).squareRoot().rounded())))
        // 3) Get seed vectors
        let seedVecs: [[Float]] = seeds.compactMap { emb.vector(forIndex: $0) }
        // Recency weights (τ=7d) using V2 bookmarks if present
        let recency = loadBookmarkTimestamps()
        let weights: [Float] = seeds.map { sid in
            if let ts = recency[sid] {
                let ageSec = max(0.0, Date().timeIntervalSince1970 - ts)
                let tau: Double = 7 * 24 * 3600
                let w = exp(-ageSec / tau)
                return Float(max(0.2, w))
            }
            return 1.0
        }
        // 4) Simple k-means init (evenly spaced seeds)
        var centroids: [[Float]] = stride(from: 0, to: seedVecs.count, by: max(1, seedVecs.count / k)).prefix(k).map { seedVecs[$0] }
        // Lloyd iterations (few steps)
        for _ in 0..<5 {
            let assign: [Int] = seedVecs.map { v in argmax(centroids.map { dot($0, v) }) }
            for c in 0..<k {
                let membersW = seedVecs.enumerated().compactMap { (i, vec) -> (vec:[Float], w:Float)? in
                    assign[i] == c ? (vec, weights[i]) : nil
                }
                let members = membersW.map { $0.vec }
                if members.isEmpty { continue }
                let centroid = normalize(weightedSumVectors(membersW))
                centroids[c] = centroid
            }
        }
        // 5) Shown filter
        let shownSet = loadShown(excludingNewerThanDays: params.noRepeatDays)
        // 6) Per cluster: score all lessons vs centroid; filter; band; pick
        var clusterPicks: [(idx:Int, score:Float)] = []
        for c in 0..<k {
            let q = centroids[c]
            let scores = emb.scores(forQuery: q)
            // Build candidate pool sorted by score desc
            let order = (0..<scores.count).sorted { scores[$0] > scores[$1] }
            var pool: [(Int,Float)] = []
            pool.reserveCapacity(params.topMPerCluster)
            for idx in order {
                if seeds.contains(idx) { continue }
                if shownSet.contains(idx) { continue }
                let s = scores[idx]
                if s < params.minCos { break }
                // maxSimilar vs seeds in this cluster approximated by global seeds
                if maxSimilarity(idx, seeds: seeds, emb: emb) > params.maxSimilar { continue }
                pool.append((idx, s))
                if pool.count >= params.topMPerCluster { break }
            }
            guard !pool.isEmpty else { continue }
            let band = percentileBand(pool, low: params.bandLowPct, high: params.bandHighPct)
            guard !band.isEmpty else { continue }
            // Random pick from band
            if let pick = band.randomElement() { clusterPicks.append(pick) }
        }
        // 7) Final pick
        let chosen: (Int,Float)
        if let p = clusterPicks.randomElement() {
            chosen = p
        } else {
            // fallback: any non-seed not shown, pick highest score to first centroid
            let q = centroids.first ?? seedVecs.first ?? Array(repeating: 0, count: emb.dim)
            let scores = emb.scores(forQuery: q)
            let order = (0..<scores.count).sorted { scores[$0] > scores[$1] }
            var alt: (Int,Float)? = nil
            for idx in order {
                if seeds.contains(idx) { continue }
                if shownSet.contains(idx) { continue }
                alt = (idx, scores[idx]); break
            }
            guard let a = alt else { return FallbackWeeklyHeuristic().pick(for: date) }
            chosen = a
        }
        // 8) Verse selection: earliest unit
        let units = ui.units(forEmbeddingIndex: chosen.0)
        let first = units.first
        let chapter = first?.chapter ?? 1
        let verse = first?.start ?? 1
        let text = lt.text(forIndex: chosen.0)
        // Persist shown
        saveShown(index: chosen.0, date: date)
        return WeeklyPick(lessonIndex: chosen.0, lessonText: text, chapter: chapter, verse: verse)
    }

    // MARK: - Helpers
    private func dot(_ a: [Float], _ b: [Float]) -> Float { zip(a,b).reduce(0) { $0 + $1.0 * $1.1 } }
    private func sumVectors(_ vs: [[Float]]) -> [Float] {
        guard let first = vs.first else { return [] }
        var out = Array(repeating: Float(0), count: first.count)
        for v in vs { for i in 0..<first.count { out[i] += v[i] } }
        return out
    }
    private func weightedSumVectors(_ vs: [(vec:[Float], w:Float)]) -> [Float] {
        guard let first = vs.first?.vec else { return [] }
        var out = Array(repeating: Float(0), count: first.count)
        for (v, w) in vs { for i in 0..<first.count { out[i] += v[i] * w } }
        return out
    }
    private func norm(_ v: [Float]) -> Float { sqrt(max(1e-12, v.reduce(0) { $0 + $1*$1 })) }
    private func normalize(_ v: [Float]) -> [Float] {
        let n = norm(v); return n > 0 ? v.map { $0 / n } : v
    }
    private func argmax(_ xs: [Float]) -> Int { xs.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0 }

    private func percentileBand(_ pool: [(Int,Float)], low: Float, high: Float) -> [(Int,Float)] {
        let scores = pool.map { $0.1 }.sorted()
        guard !scores.isEmpty else { return [] }
        let loIdx = Int((Double(low)/100.0) * Double(scores.count-1))
        let hiIdx = Int((Double(high)/100.0) * Double(scores.count-1))
        let loV = scores[max(0, min(loIdx, scores.count-1))]
        let hiV = scores[max(0, min(hiIdx, scores.count-1))]
        return pool.filter { $0.1 >= loV && $0.1 <= hiV }.sorted { $0.1 > $1.1 }
    }

    private func maxSimilarity(_ idx: Int, seeds: [Int], emb: LessonEmbeddingIndex) -> Float {
        guard let v = emb.vector(forIndex: idx) else { return 1 }
        var maxDot: Float = -1
        for s in seeds { if let sv = emb.vector(forIndex: s) { maxDot = max(maxDot, dot(v, sv)) } }
        return maxDot
    }

    private func loadBookmarkTimestamps() -> [Int: TimeInterval] {
        // Prefer V2 structure: array of {index, ts}
        if let data = SharedDefaults.defaults.data(forKey: "SavedVersesV2"),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            var map: [Int: TimeInterval] = [:]
            for obj in arr {
                if let idx = obj["index"] as? Int, let ts = obj["ts"] as? TimeInterval { map[idx] = ts }
            }
            return map
        }
        // Fallback: legacy list → give them a uniform recent timestamp
        if let legacy = SharedDefaults.defaults.array(forKey: "SavedVerses") as? [Int] {
            let now = Date().timeIntervalSince1970
            var map: [Int: TimeInterval] = [:]
            for idx in legacy { map[idx] = now }
            return map
        }
        return [:]
    }

    private func loadSeedLessonIndices() -> [Int] {
        // Pull bookmarks from UserDefaults (SavedVerses) and map via verseMap if present
        var seeds: [Int] = []
        if let array = SharedDefaults.defaults.array(forKey: "SavedVerses") as? [Int] {
            for gi in array {
                let (ch,v) = VersesInfo.getVerseFromIndex(idx: gi)
                let key = "\(ch):\(v)"
                if let lid = verseMap[key] { seeds.append(lid) }
            }
        }
        // Dedup preserving order
        var seen = Set<Int>(); var out: [Int] = []
        for s in seeds { if !seen.contains(s) { seen.insert(s); out.append(s) } }
        return out
    }

    private func loadShown(excludingNewerThanDays days: Int) -> Set<Int> {
        guard let data = SharedDefaults.defaults.data(forKey: shownKey), let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]] else { return [] }
        let cutoff = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        var set = Set<Int>()
        for obj in arr {
            if let idx = obj["index"] as? Int, let ts = obj["ts"] as? TimeInterval {
                let d = Date(timeIntervalSince1970: ts)
                if d > cutoff { set.insert(idx) }
            }
        }
        return set
    }

    private func saveShown(index: Int, date: Date) {
        var arr: [[String:Any]] = []
        if let data = SharedDefaults.defaults.data(forKey: shownKey), let existing = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]] {
            arr = existing
        }
        arr.append(["index": index, "ts": date.timeIntervalSince1970])
        if let data = try? JSONSerialization.data(withJSONObject: arr) {
            SharedDefaults.defaults.set(data, forKey: shownKey)
        }
    }
}

// MARK: - Weekly pick synchronization helpers
public struct WeeklyPickSync {
    private static let pickKeyPrefix = "weekly_pick_"

    public static func sundayStart(for date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: startOfDay) // 1 = Sunday
        if weekday == 1 {
            return startOfDay
        }
        let daysUntilSunday = (8 - weekday) % 7
        let nextSunday = cal.date(byAdding: .day, value: daysUntilSunday, to: startOfDay)!
        return cal.startOfDay(for: nextSunday)
    }

    public static func nextSundayStart(after date: Date) -> Date {
        let thisSunday = sundayStart(for: date)
        if thisSunday > date {
            return thisSunday
        }
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: 7, to: thisSunday)!
        return cal.startOfDay(for: next)
    }

    public static func loadPick(forWeekOf date: Date) -> WeeklyPick? {
        let anchor = sundayStart(for: date)
        let key = pickKeyPrefix + String(Int(anchor.timeIntervalSince1970))
        guard let dict = SharedDefaults.defaults.dictionary(forKey: key) as? [String: Any] else { return nil }
        guard let li = dict["lessonIndex"] as? Int,
              let lt = dict["lessonText"] as? String,
              let ch = dict["chapter"] as? Int,
              let vs = dict["verse"] as? Int else { return nil }
        return WeeklyPick(lessonIndex: li, lessonText: lt, chapter: ch, verse: vs)
    }

    public static func savePick(_ pick: WeeklyPick, forWeekOf date: Date) {
        let anchor = sundayStart(for: date)
        let key = pickKeyPrefix + String(Int(anchor.timeIntervalSince1970))
        let dict: [String: Any] = [
            "lessonIndex": pick.lessonIndex,
            "lessonText": pick.lessonText,
            "chapter": pick.chapter,
            "verse": pick.verse
        ]
        SharedDefaults.defaults.set(dict, forKey: key)
    }

    public static func getOrComputePick(forWeekOf date: Date, with heuristic: WeeklyHeuristic) -> WeeklyPick {
        if let existing = loadPick(forWeekOf: date) {
            return existing
        }
        let computed = heuristic.pick(for: date)
        savePick(computed, forWeekOf: date)
        return computed
    }
}

fileprivate final class FallbackWeeklyHeuristic: WeeklyHeuristic {
    private let unitsIndex: LessonUnitsIndex?
    private let lessonTexts: LessonTextsIndex?
    private let shownKey = "weekly_shown_history"

    fileprivate init() {
        self.unitsIndex = LessonUnitsIndex()
        self.lessonTexts = LessonTextsIndex()
    }

    fileprivate func pick(for date: Date) -> WeeklyPick {
        guard let ui = unitsIndex, let lt = lessonTexts, ui.count > 0, lt.count > 0 else {
            return WeeklyPick(lessonIndex: 0, lessonText: "Lesson of the Week", chapter: 1, verse: 1)
        }

        // Curated old_cluster_id list mapped to lesson indices
        let curatedOldClusterIds: Set<Int> = [77, 42, 133, 125, 218, 265, 273, 449, 645]
        var curatedLessonIndices: [Int] = []
        curatedLessonIndices.reserveCapacity(curatedOldClusterIds.count)
        for idx in 0..<ui.count {
            if let cid = ui.oldClusterId(forEmbeddingIndex: idx), curatedOldClusterIds.contains(cid) {
                curatedLessonIndices.append(idx)
            }
        }

        // 180-day no-repeat window (match WeeklyParams.noRepeatDays default)
        let shownSet = loadShown(excludingNewerThanDays: 180)

        // Try random from curated set first (excluding shown)
        let availableCurated = curatedLessonIndices.filter { !shownSet.contains($0) }
        var chosenIndex: Int? = availableCurated.randomElement()

        // If curated exhausted, pick random from all lessons excluding shown
        if chosenIndex == nil {
            let allAvailable = (0..<ui.count).filter { !shownSet.contains($0) }
            chosenIndex = allAvailable.randomElement()
        }

        // As a last resort, fall back to deterministic week-of-year
        if chosenIndex == nil {
            let cal = Calendar.current
            let week = cal.component(.weekOfYear, from: date)
            chosenIndex = max(0, (week - 1) % ui.count)
        }

        let finalIndex = chosenIndex ?? 0
        let units = ui.units(forEmbeddingIndex: finalIndex)
        let first = units.first
        let chapter = first?.chapter ?? 1
        let verse = first?.start ?? 1
        let text = lt.text(forIndex: finalIndex)
        saveShown(index: finalIndex, date: date)
        return WeeklyPick(lessonIndex: finalIndex, lessonText: text, chapter: chapter, verse: verse)
    }

    // MARK: - Shown history (shared format/key with SattvaWeeklyHeuristic)
    private func loadShown(excludingNewerThanDays days: Int) -> Set<Int> {
        guard let data = UserDefaults.standard.data(forKey: shownKey), let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]] else { return [] }
        let cutoff = Date().addingTimeInterval(TimeInterval(-days * 24 * 3600))
        var set = Set<Int>()
        for obj in arr {
            if let idx = obj["index"] as? Int, let ts = obj["ts"] as? TimeInterval {
                let d = Date(timeIntervalSince1970: ts)
                if d > cutoff { set.insert(idx) }
            }
        }
        return set
    }

    private func saveShown(index: Int, date: Date) {
        var arr: [[String:Any]] = []
        if let data = UserDefaults.standard.data(forKey: shownKey), let existing = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]] {
            arr = existing
        }
        arr.append(["index": index, "ts": date.timeIntervalSince1970])
        if let data = try? JSONSerialization.data(withJSONObject: arr) {
            UserDefaults.standard.set(data, forKey: shownKey)
        }
    }
}


