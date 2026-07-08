import Testing
@testable import Bhagavad_Gita_Verses

struct EmotionQueryBuilderTests {
    @Test func negativeRootsUseOptionB() {
        #expect(EmotionQueryBuilder.build(root: "Sad", mid: "Lonely", leaf: "Isolated") == "overcome lonely and isolated")
        #expect(EmotionQueryBuilder.build(root: "Mad", mid: "Frustrated", leaf: "Annoyed") == "overcome frustrated and annoyed")
        #expect(EmotionQueryBuilder.build(root: "Scared", mid: "Anxious", leaf: "Worried") == "overcome anxious and worried")
    }

    @Test func positiveRootsUseIFeelFormat() {
        #expect(EmotionQueryBuilder.build(root: "Joyful", mid: "Content", leaf: "Free")
                == "I feel Joyful because I feel Content, because I feel Free")
        #expect(EmotionQueryBuilder.build(root: "Powerful", mid: "Confident", leaf: "Brave")
                == "I feel Powerful because I feel Confident, because I feel Brave")
    }
}
