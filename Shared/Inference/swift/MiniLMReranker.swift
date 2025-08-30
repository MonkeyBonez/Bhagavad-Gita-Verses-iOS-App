import Foundation
import CoreML

final class MiniLMReranker {
    private let model: MLModel
    private let inputIdsName = "input_ids"
    private let maskName = "attention_mask"
    private let typeIdsName = "token_type_ids"
    private let outputName: String

    init?() {
        let subdirs = [
            "Shared/Inference/cross-encoder/Model",
            "inference/cross-encoder/Model",
            nil
        ]
        var url: URL? = nil
        for sub in subdirs {
            if url != nil { break }
            if let s = sub { url = Bundle.main.url(forResource: "MiniLML6CE", withExtension: "mlmodelc", subdirectory: s) }
            if url == nil, let s = sub { url = Bundle.main.url(forResource: "MiniLML6CE", withExtension: "mlpackage", subdirectory: s) }
        }
        if url == nil { url = Bundle.main.url(forResource: "MiniLML6CE", withExtension: "mlmodelc") }
        if url == nil { url = Bundle.main.url(forResource: "MiniLML6CE", withExtension: "mlpackage") }
        guard let modelURL = url else {
            assertionFailure("MiniLMReranker: model not found in bundle")
            return nil
        }
        // Prefer CPU/GPU to avoid ANE compile issues; fallback to CPU if needed
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuAndGPU
        var loaded: MLModel? = try? MLModel(contentsOf: modelURL, configuration: cfg)
        if loaded == nil {
            let cpuCfg = MLModelConfiguration(); cpuCfg.computeUnits = .cpuOnly
            loaded = try? MLModel(contentsOf: modelURL, configuration: cpuCfg)
        }
        guard let mdl = loaded else { return nil }
        model = mdl
        let keys = Array(model.modelDescription.outputDescriptionsByName.keys)
        print("MiniLMReranker: outputs=\(keys)")
        outputName = keys.first ?? "var_0"
    }

    func score(ids: [Int32], mask: [Int32], types: [Int32]) -> Float? {
        let n = ids.count
        guard n == mask.count && n == types.count else { return nil }
        guard let idsArr = try? MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .int32),
              let maskArr = try? MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .int32),
              let typesArr = try? MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .int32) else { return nil }
        for i in 0..<n { idsArr[i] = NSNumber(value: ids[i]); maskArr[i] = NSNumber(value: mask[i]); typesArr[i] = NSNumber(value: types[i]) }
        guard let inputs = try? MLDictionaryFeatureProvider(dictionary: [
            inputIdsName: MLFeatureValue(multiArray: idsArr),
            maskName: MLFeatureValue(multiArray: maskArr),
            typeIdsName: MLFeatureValue(multiArray: typesArr)
        ]) else { return nil }
        guard let out = try? model.prediction(from: inputs) else {
            print("MiniLMReranker: prediction failed")
            return nil
        }
        guard let arr = out.featureValue(for: outputName)?.multiArrayValue else {
            print("MiniLMReranker: output missing for key \(outputName)")
            return nil
        }
        if arr.count == 0 {
            print("MiniLMReranker: output array empty")
            return nil
        }
        let v = arr[0].floatValue
        let shape = arr.shape.map { $0.intValue }
        let first = min(arr.count, 3)
        var head: [Float] = []
        head.reserveCapacity(first)
        for i in 0..<first { head.append(arr[i].floatValue) }
        print("MiniLMReranker: out shape=\(shape) head=\(head)")
        if !v.isFinite { return nil }
        return v
    }

    func scoreBatch(query: String, passages: [String], tokenizer: PairWordPieceTokenizer, maxLen: Int = 160, maxQuery: Int = 48) -> [Float] {
        var out: [Float] = []; out.reserveCapacity(passages.count)
        for (idx, p) in passages.enumerated() {
            let enc = tokenizer.encodePair(query: query, passage: p, maxLen: maxLen, maxQuery: maxQuery)
            if idx == 0 {
                let idsPreview = enc.ids.prefix(12).map { String($0) }.joined(separator: ",")
                print("MiniLMReranker: ids=\(enc.ids.count) mask=\(enc.mask.count) types=\(enc.types.count) idsHead=[\(idsPreview)]")
            }
            out.append(score(ids: enc.ids, mask: enc.mask, types: enc.types) ?? -Float.greatestFiniteMagnitude)
        }
        return out
    }
}
