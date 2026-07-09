# On-device LLM — prototype & approach

Goal: generate a short, grounded "why does this verse apply to me?" explanation on-device
(private, offline, free), for the explanation bottom sheet (roadmap #6).

## Approaches evaluated

| Approach | Model | Bundle cost | Effort | Verdict |
|---|---|---|---|---|
| **Apple Foundation Models** | Built-in ~3B (Apple Intelligence) | **0 MB** — OS-provided | Low — native Swift API, streaming, guided generation | **Tier A** (8 GB / AI devices) |
| **MLX-Swift** | Llama-3.2-3B / Qwen2.5-1.5B (4-bit) | downloaded on demand (~0.9–1.8 GB) | Medium — package, memory tiering, tokenizer | **Tier B/C** (6/4 GB devices) |
| Core ML (converted LLM) | Small converted transformer | ~0.5–1 GB | High — conversion, KV-cache, sampling by hand | Not worth it here |
| llama.cpp / MLC | GGUF small model | ~0.7 GB+ | Medium/High — C++ interop, no native streaming API | Overkill |

The original prototype was Foundation-Models-only. That left every non-Apple-Intelligence device
(iPhone 14 and earlier — 6 GB or less, no iOS-26 AI) on the stub with no real generation. After a
local model bake-off (`utils/Scripts/llm_experiments/`) and a memory-budget study, the backend is
now **hardware-tiered** (`ExplainerTier`).

### Why Foundation Models where it's available
- **Zero bundle cost** — the model ships with the OS; we add no gigabytes to the app.
- **Native, first-class Swift**: `LanguageModelSession`, `streamResponse`, `@Generable`, guardrails.
- **Private + offline + free**, and right-sized for a 2–3 sentence grounded explanation.
- Cost: needs iOS 26 **and** an 8 GB Apple-Intelligence device — so it can't be the only backend.

### The tier ladder (`ExplainerTier.recommended`)
Pure and injectable (see `ExplainerTierTests`). Order of decision:
1. **Developer override** (`DefaultsKeys.explainerBackendOverride` = `fm`/`3b`/`1.5b`/`stub`) — lets
   an on-device build A/B a specific backend. Beats everything.
2. **Foundation Models** if `SystemLanguageModel.default.availability == .available` (8 GB + iOS 26).
3. **MLX Llama-3.2-3B** on 6 GB-class devices (`physicalMemory ≥ 5.3 GB`) — the bake-off quality
   winner (~2 GB peak RAM; fits the ~2.9 GB jetsam budget, aided by the
   `increased-memory-limit` entitlement).
4. **MLX Qwen2.5-1.5B** on 4 GB-class devices (`≥ 3.5 GB`) — the safe floor (~1.1 GB peak).
5. **Stub** below that, and as the universal fallback.

`VerseExplainerFactory.make()` maps the tier to a backend, returning Foundation Models only when it
reports `.available` at runtime and MLX only when its package is linked (`#if canImport(MLXLLM)`),
so callers never hold an explainer whose `explain` would throw.

### MLX backend (`MLXVerseExplainer`)
- Package: `mlx-swift-examples` pinned to **2.25.9** (products `MLXLLM` + `MLXLMCommon`), app target
  only — never linked into Widgets / App Intent. Added reproducibly via `add_mlx_package.rb`.
- `ModelLoader` (actor) downloads the model once from the HuggingFace Hub and caches the
  `ModelContainer`; generation streams cumulative text to match the FM backend.
- **Graceful floor:** any load/inference failure (no network on first run, OOM, jetsam) degrades to
  streaming the mapped lesson — the same behavior as the stub — instead of surfacing an error.
- Memory hygiene: `MLX.GPU.set(cacheLimit:)` keeps the Metal buffer cache small; on-demand download
  means the App Store binary stays small and each device fetches only the model it will run.

### Why not bundle the models / open items
- Bundling both models would add ~2.7 GB to every install. On-demand download (current) is better;
  a future refinement is per-tier download via Background Assets so first-run generation isn't
  gated on a live fetch.
- A pre-flight `os_proc_available_memory()` check before load (belt-and-suspenders vs. the static
  RAM tiering) and sequencing the CoreML retriever unload before the LLM load are noted refinements.

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

- Pure logic (prompt/context/stub/factory, tier ladder): unit-tested, green
  (`VerseExplainerTests`, `ExplainerTierTests`).
- Foundation Models path: compiles against the iOS 26 SDK and is invoked correctly; on the iOS 26
  Simulator it builds the session and issues the request, failing only because the Simulator has no
  provisioned model assets. Full generation needs a real Apple-Intelligence device.
- MLX path: **compiles and links against the real MLXLLM/MLXLMCommon 2.25.9 API**. On-device
  generation is intentionally not unit-tested (first `explain` downloads a multi-GB model); it is
  validated by the sideload test on a physical device (iPhone 14 Pro / A16, the 6 GB Tier B case).

## On-device test (sideload) — what to measure
The Mac bake-off answered *quality* (Llama-3.2-3B > Qwen-1.5B ≫ 1B). The phone answers what the Mac
can't: does the 3B **fit and run** on a 6 GB device?
- Force each backend via `DefaultsKeys.explainerBackendOverride` (`3b`, then `1.5b`).
- Watch: first-run download time, load time, tokens/sec, peak memory (Instruments / Xcode gauge),
  and whether the 3B is jetsammed under real memory pressure. If it is, Qwen-1.5B is the Tier B ceiling.
