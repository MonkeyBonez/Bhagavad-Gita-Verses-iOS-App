import SwiftUI

@MainActor
@Observable
final class GuidanceViewModel {
    // Inputs
    var query: String = ""
    var topK: Int = 3
    var retrieveTopK: Int = 10

    // State
    private(set) var isSearching: Bool = false
    private(set) var errorText: String? = nil
    private(set) var results: [LessonResult] = []

    // Services
    private var searchHelper: LessonSearchHelper? = nil
    private var unitsIndex: LessonUnitsIndex? = nil

    // Executes the guidance search flow and picks a target verse global index.
    // Completion is called on the main thread with an optional global index.
    func searchAndPickTarget(query override: String? = nil, completion: @escaping (Int?) -> Void) {
        errorText = nil
        results = []

        let raw = (override ?? query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            errorText = "Please enter some text."
            completion(nil)
            return
        }
        if searchHelper == nil { searchHelper = LessonSearchHelper() }
        guard let helper = searchHelper else { errorText = "Failed to initialize search."; completion(nil); return }

        isSearching = true
        let k = topK
        let rk = max(k, retrieveTopK)
        let normalized = raw.hasPrefix("query ") ? raw : ("query " + raw)

        DispatchQueue.global(qos: .userInitiated).async {
            let results = helper.search(text: normalized, topK: k, retrieveTopK: rk, doRerank: true)
            DispatchQueue.main.async {
                self.results = results
                self.isSearching = false
                guard !results.isEmpty else { completion(nil); return }

                let chosenOffset = LessonNavigationHelper.pickWeightedTopIndex(count: results.count)
                let chosen = results[chosenOffset]
                let rowIndex = Int(chosen.id)
                if self.unitsIndex == nil { self.unitsIndex = LessonUnitsIndex() }
                guard let uidx = self.unitsIndex else { completion(nil); return }

                let units = uidx.units(forEmbeddingIndex: rowIndex)
                if let target = LessonNavigationHelper.pickRandomTarget(from: units) {
                    let globalIdx = LessonNavigationHelper.globalIndex(forChapter: target.chapter, verse: target.verse)
                    completion(globalIdx)
                } else {
                    completion(nil)
                }
            }
        }
    }
}


