import Testing
import Foundation
@testable import Bhagavad_Gita_Verses

struct VerseExplainerTests {

    private func sampleContext(situation: String? = nil) -> VerseSceneContext {
        GitaSceneProvider.context(chapter: 2, verse: 47,
                                  verseText: "You have a right to your actions, but never to the fruits of your actions.",
                                  lesson: "Your right is to your work, not its rewards.")
    }

    // MARK: - Context pack

    @Test func sceneProviderGivesChapterThemeAndScene() {
        let c = sampleContext()
        #expect(c.chapter == 2 && c.verse == 47)
        #expect(!c.chapterTheme.isEmpty)
        #expect(!c.scene.isEmpty)
        #expect(c.speakers.contains("Krishna"))
    }

    @Test func sceneProviderFallsBackForUnknownChapter() {
        let c = GitaSceneProvider.context(chapter: 99, verse: 1, verseText: "x", lesson: nil)
        #expect(!c.chapterTheme.isEmpty)   // graceful default, never empty
        #expect(!c.scene.isEmpty)
    }

    // MARK: - Prompt construction

    @Test func promptGroundsInSceneAndVerse() {
        let p = ExplanationPrompt.prompt(sampleContext(), userSituation: nil)
        #expect(p.contains("Chapter 2"))
        #expect(p.contains("2:47"))
        #expect(p.contains("right to your actions"))
        #expect(p.contains("Arjuna"))            // cast is included as grounding
        #expect(p.contains("everyday life"))     // no-situation branch
    }

    @Test func promptWeavesInUserSituation() {
        let p = ExplanationPrompt.prompt(sampleContext(), userSituation: "I'm anxious about a work deadline")
        #expect(p.contains("work deadline"))
        #expect(p.contains("their situation"))
    }

    @Test func promptOmitsEmptySituation() {
        let p = ExplanationPrompt.prompt(sampleContext(), userSituation: "   ")
        #expect(p.contains("everyday life"))
        #expect(!p.contains("The reader says"))
    }

    // MARK: - Stub fallback

    @Test func stubReportsFallbackButStillStreamsLesson() async throws {
        let stub = StubVerseExplainer()
        // The whole point of C2: the stub is a *fallback*, not a dead end — it still yields content.
        if case .fallback = stub.availability {} else { Issue.record("stub should report .fallback") }
        var chunks: [String] = []
        for try await s in stub.explain(sampleContext(), userSituation: nil) { chunks.append(s) }
        #expect(chunks.last == "Your right is to your work, not its rewards.")
        #expect(!(chunks.last ?? "").isEmpty)
    }

    // MARK: - Factory

    @Test func factoryReturnsAnExplainer() {
        // Construction is lazy (no model download) and `availability` is a total function —
        // this must never crash regardless of device tier or which backend is selected.
        let e = VerseExplainerFactory.make()
        _ = e.availability
    }

    // NOTE: on-device generation is deliberately NOT exercised here. Through the factory it could
    // select the MLX backend, whose first `explain` downloads a multi-GB model — inappropriate for
    // a unit test. MLX integration is validated by (a) the app compiling+linking against the real
    // MLXLLM/MLXLMCommon API and (b) the on-device sideload test. Stub streaming is covered above;
    // tier selection is covered by ExplainerTierTests.
}
