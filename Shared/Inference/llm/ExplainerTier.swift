import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Chooses the on-device explanation backend from the device's hardware capability.
///
/// Rationale (see `utils/Scripts/llm_experiments/` bake-off + `ONDEVICE_LLM.md`):
/// - **Apple Intelligence / Foundation Models** needs an 8 GB device (iPhone 15 Pro+, 16,
///   M-series) on iOS 26 — 0 MB bundle, best native integration.
/// - **MLX Llama-3.2-3B** (~2 GB peak RAM) is the quality winner but only fits 6 GB-class
///   devices within their jetsam budget.
/// - **MLX Qwen2.5-1.5B** (~1.1 GB peak) is the safe floor for 4 GB-class devices.
/// - Below that — or if a model fails to load — the stub streams the mapped lesson.
///
/// `ProcessInfo.physicalMemory` reports a little under the marketing figure (a "6 GB" phone
/// reports ~5.6 GB), so the thresholds sit below the round numbers. Pure and injectable so
/// the tiering can be unit-tested without a device.
enum ExplainerTier: String, Equatable {
    case foundationModels
    case mlxLarge     // Llama-3.2-3B — quality winner, 6 GB-class
    case mlxSmall     // Qwen2.5-1.5B — safe floor, 4 GB-class
    case stub         // lesson text only

    /// Bytes-per-GiB, so the thresholds read in GB.
    private static let giB = 1_073_741_824.0

    /// Parse a developer override string (App Group defaults) into a tier.
    static func override(_ raw: String) -> ExplainerTier? {
        switch raw.lowercased() {
        case "fm", "foundation", "foundationmodels": return .foundationModels
        case "3b", "large", "mlxlarge", "llama", "llama3b": return .mlxLarge
        case "1.5b", "1_5b", "small", "mlxsmall", "qwen": return .mlxSmall
        case "stub", "off", "lesson", "none": return .stub
        default: return nil
        }
    }

    /// The backend this device should use. Honors a developer override first, then Apple
    /// Intelligence availability, then falls back to a RAM-tiered MLX model or the stub.
    static func recommended(
        memoryBytes: UInt64 = ProcessInfo.processInfo.physicalMemory,
        defaults: UserDefaults = SharedDefaults.defaults,
        foundationModelsAvailable: Bool = ExplainerTier.isFoundationModelsAvailable
    ) -> ExplainerTier {
        if let raw = defaults.string(forKey: DefaultsKeys.explainerBackendOverride),
           let forced = override(raw) {
            return forced
        }
        if foundationModelsAvailable { return .foundationModels }

        let gb = Double(memoryBytes) / giB
        if gb >= 5.3 { return .mlxLarge }   // 6 GB-class (reports ~5.6)
        if gb >= 3.5 { return .mlxSmall }   // 4 GB-class (reports ~3.7)
        return .stub
    }

    /// Whether Foundation Models reports itself usable right now (iOS 26 + eligible device
    /// with Apple Intelligence enabled and the model downloaded).
    static var isFoundationModelsAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }
}
