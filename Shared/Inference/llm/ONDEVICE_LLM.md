# On-device LLM — prototype & approach

Goal: generate a short, grounded "why does this verse apply to me?" explanation on-device
(private, offline, free), for the explanation bottom sheet (roadmap #6).

## Approaches evaluated

| Approach | Model | Bundle cost | Effort | Verdict |
|---|---|---|---|---|
| **Apple Foundation Models** | Built-in ~3B (Apple Intelligence) | **0 MB** — OS-provided | Low — native Swift API, streaming, guided generation | **Chosen** |
| MLX-Swift | e.g. Llama-3.2-1B / Qwen2.5-1.5B (4-bit) | ~0.7–1.1 GB in-app | Medium — bundle weights, manage memory, tokenizer | Fallback for pre-iOS-26 |
| Core ML (converted LLM) | Small converted transformer | ~0.5–1 GB | High — conversion, KV-cache, sampling by hand | Not worth it here |
| llama.cpp / MLC | GGUF small model | ~0.7 GB+ | Medium/High — C++ interop, no native streaming API | Overkill |

### Why Foundation Models
- **Zero bundle cost** — the model ships with the OS; we add no gigabytes to the app.
- **Native, first-class Swift**: `LanguageModelSession`, async `respond`/`streamResponse`,
  `@Generable` guided output, built-in guardrails.
- **Private + offline + free** — no API keys, no per-token cost, nothing leaves the device.
- **Right-sized**: a 2–3 sentence grounded explanation is exactly what a ~3B model does well.

### The cost: availability
Foundation Models needs iOS 26+ **and** an Apple-Intelligence-capable device with the model
provisioned. So the design is availability-first:
- `SystemLanguageModel.default.availability` gates use; reasons (`deviceNotEligible`,
  `appleIntelligenceNotEnabled`, `modelNotReady`) map to human copy.
- `VerseExplainerFactory.make()` returns the Foundation Models backend on iOS 26+, else a
  `StubVerseExplainer` that degrades to showing the lesson. MLX-Swift is the natural drop-in for
  a real pre-26 backend if we decide older devices need generation.

## Design (`VerseExplainer.swift`)

- `VerseExplainer` protocol → `explain(context, userSituation) -> AsyncThrowingStream<String>`
  (streams cumulative text for live rendering).
- `VerseSceneContext` + `GitaSceneProvider` = the **context pack**: cast (Arjuna/Krishna/Sanjaya),
  per-chapter theme and scene, the verse, and the app's mapped lesson — fed to the model so the
  explanation is grounded in the actual moment, not generic spirituality. (This is the RTF idea:
  give the model who/where/what before asking "why does this apply to me".)
- `ExplanationPrompt` (pure, unit-tested) builds instructions + prompt; weaves in the user's
  situation when provided.

## Verification status

- Pure logic (prompt/context/stub/factory): unit-tested, green (`VerseExplainerTests`).
- Foundation Models path: **compiles against the iOS 26 SDK and is invoked correctly** — on the
  iOS 26 Simulator it builds the session and issues the request, then fails only because the
  Simulator has no provisioned model assets (`com.apple.modelcatalog` empty). Full token
  generation requires a real device with Apple Intelligence downloaded. The availability enum and
  the tolerant live smoke handle this boundary without a hard failure.
