import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Context pack (grounding for the LLM)

/// The scene around a verse, fed to the model so its explanation is grounded in the
/// actual moment of the Gita rather than generic spirituality. This is the "context pack"
/// idea: who is speaking, what is happening, the chapter's theme — the basics a reader needs.
struct VerseSceneContext {
    let chapter: Int
    let verse: Int
    let verseText: String
    /// The app's mapped one-line lesson for this verse, if any.
    let lesson: String?
    /// One-line description of what is happening at this point in the story.
    let scene: String
    /// The chapter's overarching theme.
    let chapterTheme: String
    /// Who is speaking / present in this passage.
    let speakers: String
}

/// Supplies the scene context for any chapter. Compact, on-device, no network — enough
/// for the model to place a verse without shipping a commentary corpus.
enum GitaSceneProvider {
    /// The standing cast, so the model never has to guess who is who.
    static let cast = """
    Cast: Arjuna, a warrior prince paralyzed by doubt on a battlefield; Krishna, his \
    charioteer and guide, who delivers the teaching; Sanjaya, who narrates the scene to the \
    blind king Dhritarashtra.
    """

    private static let chapters: [Int: (theme: String, scene: String, speakers: String)] = [
        1:  ("Arjuna's despair", "Facing his own kin across the battlefield, Arjuna loses his nerve and refuses to fight.", "Arjuna to Krishna"),
        2:  ("The nature of the self and steady action", "Krishna begins the core teaching: act without clinging to results.", "Krishna to Arjuna"),
        3:  ("Action as service", "Krishna argues no one can avoid action, so act selflessly.", "Krishna to Arjuna"),
        4:  ("Knowledge behind action", "Krishna explains how wisdom frees action from its grip.", "Krishna to Arjuna"),
        5:  ("Renunciation and action reconciled", "Krishna shows that acting selflessly and renouncing lead to the same peace.", "Krishna to Arjuna"),
        6:  ("Meditation and self-mastery", "Krishna teaches how to steady a restless mind.", "Krishna to Arjuna"),
        7:  ("Knowledge and realization", "Krishna describes how the divine underlies all things.", "Krishna to Arjuna"),
        8:  ("The imperishable and the final moment", "Krishna on what endures and how a life's focus shapes its end.", "Krishna to Arjuna"),
        9:  ("The royal secret of devotion", "Krishna reveals that sincere devotion, however humble, is enough.", "Krishna to Arjuna"),
        10: ("Divine glory in all things", "Krishna names where his presence shows most vividly in the world.", "Krishna to Arjuna"),
        11: ("The cosmic vision", "Krishna reveals his overwhelming universal form; Arjuna is awed and humbled.", "Krishna and Arjuna"),
        12: ("The path of devotion", "Krishna describes the qualities of a steady, good-hearted person.", "Krishna to Arjuna"),
        13: ("The field and its knower", "Krishna distinguishes the body from the awareness that observes it.", "Krishna to Arjuna"),
        14: ("The three forces that drive us", "Krishna maps clarity, restlessness, and inertia as the forces behind behavior.", "Krishna to Arjuna"),
        15: ("The supreme person", "Krishna on cutting attachment and finding what is highest.", "Krishna to Arjuna"),
        16: ("Divine and destructive traits", "Krishna contrasts the qualities that free a person with those that ruin them.", "Krishna to Arjuna"),
        17: ("Faith in three forms", "Krishna shows how temperament shapes what we eat, say, and give.", "Krishna to Arjuna"),
        18: ("Freedom through surrender", "Krishna's closing summation: do your own duty, release the results.", "Krishna to Arjuna"),
    ]

    static func context(chapter: Int, verse: Int, verseText: String, lesson: String?) -> VerseSceneContext {
        let c = chapters[chapter] ?? ("A teaching from the Gita", "Krishna counsels Arjuna.", "Krishna to Arjuna")
        return VerseSceneContext(chapter: chapter, verse: verse, verseText: verseText,
                                 lesson: lesson, scene: c.scene, chapterTheme: c.theme, speakers: c.speakers)
    }
}

// MARK: - Explainer abstraction

enum ExplainerAvailability: Equatable {
    /// On-device generation works — `explain` streams a model response.
    case available
    /// On-device generation isn't available here (older OS, ineligible device, Apple Intelligence
    /// off, model still downloading). The associated string is a short human-readable note; the
    /// feature still degrades gracefully — `explain` streams the mapped lesson instead of failing.
    case fallback(String)
}

/// Generates a short, grounded "why does this apply to me?" explanation for a verse.
/// Implementations stream cumulative text so the UI can render it as it arrives.
protocol VerseExplainer {
    var availability: ExplainerAvailability { get }
    func explain(_ context: VerseSceneContext, userSituation: String?) -> AsyncThrowingStream<String, Error>
}

/// Picks the best available explainer for this device. Returns the Foundation Models backend only
/// when it reports `.available` at runtime — otherwise the stub, so callers never hold an explainer
/// whose `explain` would throw. This is what makes the graceful lesson fallback actually reachable.
enum VerseExplainerFactory {
    static func make() -> VerseExplainer {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let fm = FoundationModelsVerseExplainer()
            if case .available = fm.availability { return fm }
        }
        #endif
        return StubVerseExplainer()
    }
}

// MARK: - Prompt construction (pure, unit-testable)

enum ExplanationPrompt {
    static let instructions = """
    You explain how a single line from the Bhagavad Gita applies to an ordinary person's life today.
    Rules:
    - Be concrete and practical. No preaching, no religious jargon, no "thou".
    - 2–3 short sentences, plain modern English.
    - Ground your explanation in the scene provided (who is speaking, what is happening), but speak to the reader's own life.
    - If the reader shared a situation, connect the verse directly to it.
    """

    static func prompt(_ c: VerseSceneContext, userSituation: String?) -> String {
        var p = """
        \(GitaSceneProvider.cast)

        Chapter \(c.chapter) — \(c.chapterTheme).
        Scene: \(c.scene) (\(c.speakers))
        Verse \(c.chapter):\(c.verse): "\(c.verseText)"
        """
        if let lesson = c.lesson, !lesson.isEmpty {
            p += "\nThe app frames this as: \"\(lesson)\""
        }
        if let s = userSituation?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            p += "\n\nThe reader says: \"\(s)\"\nExplain how this verse speaks to their situation."
        } else {
            p += "\n\nExplain why this verse still matters for someone's everyday life."
        }
        return p
    }
}

// MARK: - Stub fallback (older OS / model unavailable)

/// Used when no on-device model is available. Returns the lesson (or verse) with a short frame,
/// so the feature degrades gracefully instead of disappearing.
struct StubVerseExplainer: VerseExplainer {
    var availability: ExplainerAvailability {
        .fallback("On-device explanations need Apple Intelligence — here's the heart of this verse.")
    }

    func explain(_ context: VerseSceneContext, userSituation: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let base = context.lesson ?? context.verseText
            continuation.yield(base)
            continuation.finish()
        }
    }
}

// MARK: - Foundation Models backend (on-device LLM, iOS 26+)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct FoundationModelsVerseExplainer: VerseExplainer {
    var availability: ExplainerAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .fallback(Self.describe(reason))
        }
    }

    func explain(_ context: VerseSceneContext, userSituation: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let session = LanguageModelSession(instructions: ExplanationPrompt.instructions)
                    let options = GenerationOptions(temperature: 0.5, maximumResponseTokens: 220)
                    let prompt = ExplanationPrompt.prompt(context, userSituation: userSituation)
                    for try await snapshot in session.streamResponse(to: prompt, options: options) {
                        continuation.yield(snapshot.content)   // cumulative text
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:          return "This device doesn't support on-device intelligence."
        case .appleIntelligenceNotEnabled:return "Turn on Apple Intelligence in Settings to enable explanations."
        case .modelNotReady:              return "The on-device model is still downloading. Try again shortly."
        @unknown default:                 return "On-device model unavailable."
        }
    }
}
#endif
