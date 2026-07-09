import Testing
@testable import Bhagavad_Gita_Verses

struct EmotionQueryBuilderTests {
    @Test func negativeRootsUseOptionB() {
        #expect(EmotionQueryBuilder.build(root: "Sad", mid: "Lonely", leaf: "Isolated") == "overcome lonely and isolated")
        #expect(EmotionQueryBuilder.build(root: "Mad", mid: "Frustrated", leaf: "Annoyed") == "overcome frustrated and annoyed")
        #expect(EmotionQueryBuilder.build(root: "Scared", mid: "Anxious", leaf: "Worried") == "overcome anxious and worried")
    }

    @Test func positiveRootsUseOptionC() {
        #expect(EmotionQueryBuilder.build(root: "Joyful", mid: "Content", leaf: "Free")
                == "cultivate content and free, deepen joyful")
        #expect(EmotionQueryBuilder.build(root: "Powerful", mid: "Confident", leaf: "Brave")
                == "cultivate confident and brave, deepen powerful")
        #expect(EmotionQueryBuilder.build(root: "Peaceful", mid: "Loving", leaf: "Tender")
                == "cultivate loving and tender, deepen peaceful")
    }
}
