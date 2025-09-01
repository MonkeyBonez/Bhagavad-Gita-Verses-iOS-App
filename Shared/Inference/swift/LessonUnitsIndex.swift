import Foundation

public struct UnitRange: Decodable {
    public let chapter: Int
    public let start: Int
    public let end: Int
}

private struct LessonUnitsEntry: Decodable {
    let old_cluster_id: Int?
    let units: [UnitRange]
}

public final class LessonUnitsIndex {
    private let entries: [LessonUnitsEntry]

    public init?() {
        // Try to locate lesson_units.json in bundle
        let candidates: [URL?] = [
            Bundle.main.url(forResource: "lesson_units", withExtension: "json"),
        ]
        guard let url = candidates.compactMap({ $0 }).first else {
            assertionFailure("LessonUnitsIndex: lesson_units.json not found in bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([LessonUnitsEntry].self, from: data)
            self.entries = decoded
        } catch {
            print("LessonUnitsIndex: failed to load/parse lesson_units.json: \(error)")
            return nil
        }
    }

    public func units(forEmbeddingIndex index: Int) -> [UnitRange] {
        guard index >= 0, index < entries.count else { return [] }
        return entries[index].units
    }

    public func oldClusterId(forEmbeddingIndex index: Int) -> Int? {
        guard index >= 0, index < entries.count else { return nil }
        return entries[index].old_cluster_id
    }
}



