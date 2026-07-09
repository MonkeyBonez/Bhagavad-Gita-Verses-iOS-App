import Testing
import Foundation
@testable import Bhagavad_Gita_Verses

/// The hardware-tiering decision is pure and injectable, so the whole ladder
/// (Apple Intelligence → 3B → 1.5B → stub) is exercised here without a device.
struct ExplainerTierTests {

    /// A clean, isolated defaults suite per call (no override key set).
    private func cleanDefaults() -> UserDefaults {
        let name = "ExplainerTierTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func gb(_ value: Double) -> UInt64 { UInt64(value * 1_073_741_824.0) }

    // MARK: - RAM ladder (Apple Intelligence unavailable)

    @Test func eightGBDeviceGetsLargeModel() {
        let t = ExplainerTier.recommended(memoryBytes: gb(7.6), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false)
        #expect(t == .mlxLarge)
    }

    @Test func sixGBDeviceGetsLargeModel() {
        // A "6 GB" phone reports ~5.6 GB.
        let t = ExplainerTier.recommended(memoryBytes: gb(5.6), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false)
        #expect(t == .mlxLarge)
    }

    @Test func fourGBDeviceGetsSmallModel() {
        let t = ExplainerTier.recommended(memoryBytes: gb(3.7), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false)
        #expect(t == .mlxSmall)
    }

    @Test func threeGBDeviceFallsBackToStub() {
        let t = ExplainerTier.recommended(memoryBytes: gb(2.8), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false)
        #expect(t == .stub)
    }

    // MARK: - Threshold boundaries

    // Boundaries tested with a clear margin either side (the ~5.3 / ~3.5 GB cut points), not on
    // the exact float edge — a UInt64 round-trip of `x * giB` lands just under x and would flip a
    // hairline == check. Real devices report ~5.6 / ~3.7, never the exact boundary.
    @Test func aroundLargeThreshold() {
        #expect(ExplainerTier.recommended(memoryBytes: gb(5.4), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false) == .mlxLarge)
        #expect(ExplainerTier.recommended(memoryBytes: gb(5.2), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false) == .mlxSmall)
    }

    @Test func aroundSmallThreshold() {
        #expect(ExplainerTier.recommended(memoryBytes: gb(3.6), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false) == .mlxSmall)
        #expect(ExplainerTier.recommended(memoryBytes: gb(3.4), defaults: cleanDefaults(),
                                          foundationModelsAvailable: false) == .stub)
    }

    // MARK: - Apple Intelligence wins when available

    @Test func foundationModelsPreferredRegardlessOfRAM() {
        let t = ExplainerTier.recommended(memoryBytes: gb(5.6), defaults: cleanDefaults(),
                                          foundationModelsAvailable: true)
        #expect(t == .foundationModels)
    }

    // MARK: - Developer override beats everything (for on-device A/B testing)

    @Test func overrideForcesSmallModelEvenWithFoundationModels() {
        let d = cleanDefaults()
        d.set("1.5b", forKey: DefaultsKeys.explainerBackendOverride)
        let t = ExplainerTier.recommended(memoryBytes: gb(8), defaults: d,
                                          foundationModelsAvailable: true)
        #expect(t == .mlxSmall)
    }

    @Test func overrideForcesStub() {
        let d = cleanDefaults()
        d.set("stub", forKey: DefaultsKeys.explainerBackendOverride)
        let t = ExplainerTier.recommended(memoryBytes: gb(8), defaults: d,
                                          foundationModelsAvailable: true)
        #expect(t == .stub)
    }

    @Test func unknownOverrideIsIgnored() {
        let d = cleanDefaults()
        d.set("banana", forKey: DefaultsKeys.explainerBackendOverride)
        let t = ExplainerTier.recommended(memoryBytes: gb(5.6), defaults: d,
                                          foundationModelsAvailable: false)
        #expect(t == .mlxLarge)   // falls through to the RAM ladder
    }

    @Test func overrideAliasesParse() {
        #expect(ExplainerTier.override("fm") == .foundationModels)
        #expect(ExplainerTier.override("3B") == .mlxLarge)
        #expect(ExplainerTier.override("llama3b") == .mlxLarge)
        #expect(ExplainerTier.override("qwen") == .mlxSmall)
        #expect(ExplainerTier.override("lesson") == .stub)
        #expect(ExplainerTier.override("nonsense") == nil)
    }
}
