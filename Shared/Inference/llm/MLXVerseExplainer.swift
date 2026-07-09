import Foundation

// Compiles only when the MLX-Swift LLM libraries are linked into the target (the app target).
// In the Widgets / App Intent extensions — where MLX is intentionally not linked — this whole
// file drops out and `VerseExplainerFactory` returns the stub instead. Guard the imports so the
// project still builds before the Swift package is added.
#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon

/// On-device explainer backed by MLX-Swift running a 4-bit–quantized small LLM
/// (Llama-3.2-3B on 6 GB-class devices, Qwen2.5-1.5B on 4 GB-class). Selected by
/// `ExplainerTier` for devices without Apple Intelligence. The model is downloaded once
/// (HuggingFace Hub) and cached in `ModelLoader`; generation streams *cumulative* text to
/// match `FoundationModelsVerseExplainer`. Any load/inference failure degrades to the mapped
/// lesson rather than surfacing an error — the same graceful floor as the stub.
final class MLXVerseExplainer: VerseExplainer, Sendable {
    private let configuration: ModelConfiguration
    private let loader: ModelLoader

    init(configuration: ModelConfiguration, loader: ModelLoader = .shared) {
        self.configuration = configuration
        self.loader = loader
    }

    /// MLX runs on any Metal device (A12+, iOS 16+); the tier selector already decided this
    /// backend is appropriate, so from the UI's perspective generation is available.
    var availability: ExplainerAvailability { .available }

    func explain(_ context: VerseSceneContext, userSituation: String?) -> AsyncThrowingStream<String, Error> {
        let configuration = self.configuration
        let loader = self.loader
        return AsyncThrowingStream { continuation in
            let task = Task {
                let system = ExplanationPrompt.instructions
                let user = ExplanationPrompt.prompt(context, userSituation: userSituation)
                do {
                    // Keep the Metal buffer cache small — matters on 6 GB devices under pressure.
                    MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
                    // Surface first-run download progress in the stream (the UI renders the
                    // latest snapshot, so these are replaced once real tokens arrive). Without
                    // this, a ~1–2 GB fetch hides behind a bare spinner and reads as a hang.
                    let container = try await loader.container(for: configuration) { pct in
                        continuation.yield("Downloading the on-device model — \(pct)%\nThis happens once; after that, explanations are instant and offline.")
                    }
                    continuation.yield("Reading the verse…")
                    try await container.perform { (ctx: ModelContext) in
                        let input = try await ctx.processor.prepare(
                            input: UserInput(chat: [.system(system), .user(user)]))
                        let params = GenerateParameters(maxTokens: 220, temperature: 0.5)
                        let stream = try MLXLMCommon.generate(
                            input: input, parameters: params, context: ctx)
                        var acc = ""
                        for await item in stream {
                            if Task.isCancelled { break }
                            if let chunk = item.chunk {
                                acc += chunk
                                continuation.yield(acc)   // cumulative, like the FM backend
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    // Graceful floor: show the mapped lesson instead of an error.
                    continuation.yield(context.lesson ?? context.verseText)
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Caches one loaded `ModelContainer` per configuration so the weights aren't reloaded on
/// every explanation. Actor-isolated to serialize concurrent first-loads into a single download.
actor ModelLoader {
    static let shared = ModelLoader()
    private var containers: [String: ModelContainer] = [:]

    /// `progress` reports whole percentages (0–100) during a first-run Hub download; it isn't
    /// called when the model is already cached on disk or in memory.
    func container(for config: ModelConfiguration,
                   progress: (@Sendable (Int) -> Void)? = nil) async throws -> ModelContainer {
        if let cached = containers[config.name] { return cached }
        let container = try await LLMModelFactory.shared.loadContainer(configuration: config) { p in
            progress?(Int(p.fractionCompleted * 100))
        }
        containers[config.name] = container
        return container
    }
}

extension MLXVerseExplainer {
    /// 6 GB-class / Apple-Intelligence-capable-but-off devices: the quality winner.
    static func large() -> VerseExplainer { MLXVerseExplainer(configuration: LLMRegistry.llama3_2_3B_4bit) }
    /// 4 GB-class devices: the safe, lighter model.
    static func small() -> VerseExplainer { MLXVerseExplainer(configuration: LLMRegistry.qwen2_5_1_5b) }
}
#endif
