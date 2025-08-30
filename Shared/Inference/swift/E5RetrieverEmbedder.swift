import Foundation
import CoreML

final class E5RetrieverEmbedder {
    private let model: MLModel
    private let inputIdsName: String = "input_ids"
    private let attentionMaskName: String = "attention_mask"
    private let outputName: String

    init?(computeUnits: MLComputeUnits = .cpuAndGPU) {
        // Prefer Shared/Inference path; fallback to lowercase inference and bundle root
        let subdirs = [
            "Shared/Inference/retriever/Model",
            "inference/retriever/Model",
            nil
        ]
        var url: URL? = nil
        for sub in subdirs {
            if url != nil { break }
            if let s = sub { url = Bundle.main.url(forResource: "E5SmallV2", withExtension: "mlmodelc", subdirectory: s) }
            if url == nil, let s = sub { url = Bundle.main.url(forResource: "E5SmallV2", withExtension: "mlpackage", subdirectory: s) }
        }
        if url == nil { url = Bundle.main.url(forResource: "E5SmallV2", withExtension: "mlmodelc") }
        if url == nil { url = Bundle.main.url(forResource: "E5SmallV2", withExtension: "mlpackage") }
        guard let modelURL = url else { return nil }
        // Prefer CPU/GPU to avoid ANE compile issues; fallback to CPU
        let config = MLModelConfiguration()
        config.computeUnits = computeUnits
        var loaded: MLModel? = try? MLModel(contentsOf: modelURL, configuration: config)
        if loaded == nil {
            let cpuCfg = MLModelConfiguration(); cpuCfg.computeUnits = .cpuOnly
            loaded = try? MLModel(contentsOf: modelURL, configuration: cpuCfg)
        }
        guard let mdl = loaded else { return nil }
        self.model = mdl
        self.outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "var_0"
    }

    func embed(inputIds: [Int32], attentionMask: [Int32]) -> [Float]? {
        guard inputIds.count == attentionMask.count, !inputIds.isEmpty else { return nil }
        let seqLen = inputIds.count
        guard let idsArray = try? MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32),
              let maskArray = try? MLMultiArray(shape: [1, NSNumber(value: seqLen)], dataType: .int32) else {
            return nil
        }
        for i in 0..<seqLen { idsArray[i] = NSNumber(value: inputIds[i]); maskArray[i] = NSNumber(value: attentionMask[i]) }
        guard let inputFeatures = try? MLDictionaryFeatureProvider(dictionary: [
            inputIdsName: MLFeatureValue(multiArray: idsArray),
            attentionMaskName: MLFeatureValue(multiArray: maskArray)
        ]) else { return nil }
        guard let out = try? model.prediction(from: inputFeatures), let outArray = out.featureValue(for: outputName)?.multiArrayValue else { return nil }
        var result = [Float](repeating: 0, count: outArray.count)
        for i in 0..<outArray.count { result[i] = outArray[i].floatValue }
        return result
    }
}


