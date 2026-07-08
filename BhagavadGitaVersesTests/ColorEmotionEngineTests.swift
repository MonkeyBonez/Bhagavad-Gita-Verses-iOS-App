import SwiftUI
import Testing
@testable import Bhagavad_Gita_Verses

struct ColorEmotionEngineTests {
    @Test func returnsFiveRankedProbabilities() {
        let result = ColorEmotionEngine().evaluate(color: .red)

        #expect(result.top5.count == 5)
        let scores = result.top5.map { $0.1 }
        #expect(scores == scores.sorted(by: >))                    // descending
        #expect(result.top5.allSatisfy { $0.1 >= 0 && $0.1 <= 1 }) // valid probabilities
    }

    @Test func distinctColorsProduceDistinctTopEmotions() {
        let engine = ColorEmotionEngine()
        let red = engine.evaluate(color: .red).top5.first?.0
        let blue = engine.evaluate(color: .blue).top5.first?.0

        #expect(red != nil)
        #expect(blue != nil)
        #expect(red != blue)
    }
}
