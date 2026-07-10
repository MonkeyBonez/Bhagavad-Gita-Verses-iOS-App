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

    // MARK: - Lesson-first prompt (bake-off Mode B — the shipping framing)

    @Test func lessonPromptLeadsWithLessonNotScene() {
        let p = ExplanationPrompt.lessonPrompt(sampleContext(), userSituation: "anxious about a deadline")
        #expect(p.hasPrefix("The lesson: \"Your right is to your work, not its rewards.\""))
        #expect(p.contains("do not quote"))            // verse is a source note only
        #expect(p.contains("anxious about a deadline"))
        #expect(!p.contains("Cast:"))                  // no battlefield retelling material
        #expect(!p.contains("Chapter 2 —"))
    }

    @Test func lessonPromptFallsBackToVerseTextWhenNoLesson() {
        let c = GitaSceneProvider.context(chapter: 2, verse: 47,
                                          verseText: "You have a right to your actions.",
                                          lesson: nil)
        let p = ExplanationPrompt.lessonPrompt(c, userSituation: nil)
        #expect(p.hasPrefix("The lesson: \"You have a right to your actions.\""))
        #expect(p.contains("ordinary life"))           // no-situation branch
    }

    @Test func lessonInstructionsForbidStorytelling() {
        let i = ExplanationPrompt.instructions(for: .lesson)
        #expect(i.contains("Do not retell"))
        #expect(i.contains("No sign-off"))
        // and the style dispatcher routes correctly
        #expect(ExplanationPrompt.instructions(for: .verse) == ExplanationPrompt.instructions)
        #expect(ExplanationPrompt.prompt(sampleContext(), userSituation: nil, style: .lesson)
                == ExplanationPrompt.lessonPrompt(sampleContext(), userSituation: nil))
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

    // MARK: - View model over the fallback backend

    /// Regression: on a device with no on-device model, `.fallback` must NOT block generation —
    /// the sheet auto-streams the mapped lesson. (The original view model treated fallback as a
    /// dead end and rendered an empty sheet on every non-Apple-Intelligence device.)
    @Test @MainActor func viewModelStreamsStubLessonDespiteFallback() async throws {
        let vm = VerseExplanationViewModel(
            chapter: 2, verse: 47,
            verseText: "You have a right to your actions, but never to the fruits of your actions.",
            lesson: "Your right is to your work, not its rewards.",
            explainer: StubVerseExplainer())
        #expect(vm.fallbackNote != nil)   // note shown…
        #expect(vm.canGenerate)           // …but generation still allowed
        vm.generate(situation: nil)
        for _ in 0..<200 {                // stub is instant; poll briefly for the task hop
            if vm.phase == .done { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(vm.phase == .done)
        #expect(vm.text == "Your right is to your work, not its rewards.")
    }

    /// The bundled verse→lesson map must resolve for a verse the corpus covers (2:47),
    /// so the sheet call site never regresses to `lesson: nil`.
    @Test func verseLessonMapResolvesKnownVerse() {
        let lesson = VerseLessonMap.lesson(chapter: 2, verse: 47)
        #expect(lesson?.isEmpty == false)
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
