import Foundation
import Accelerate

final class LessonEmbeddingIndex {
    struct Meta: Codable { let count: Int; let dim: Int; let ids: [Int32]; let texts: [String]; let model: String; let source: String? }
    private let _dim: Int
    private let _count: Int
    private let ids: [Int32]
    private let texts: [String]
    private let buffer: UnsafeMutableRawPointer
    private let byteCount: Int

    init?() {
        func find(_ name: String, _ ext: String) -> URL? {
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Shared/Inference/retriever/Index") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "inference/retriever/Index") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Inference/ModelAssets") { return u }
            return Bundle.main.url(forResource: name, withExtension: ext)
        }
        guard let metaURL = find("lessons_meta", "json"), let binURL = find("lessons_f32", "bin") else { return nil }
        do {
            let data = try Data(contentsOf: metaURL)
            let meta = try JSONDecoder().decode(Meta.self, from: data)
            _dim = meta.dim; _count = meta.count; ids = meta.ids; texts = meta.texts
        } catch { return nil }
        do {
            let fh = try FileHandle(forReadingFrom: binURL)
            let size = try fh.seekToEnd(); try fh.seek(toOffset: 0)
            byteCount = Int(size)
            buffer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Float>.alignment)
            let data = try fh.readToEnd() ?? Data(); data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: data.count)
            try fh.close()
        } catch { return nil }
    }
    deinit { buffer.deallocate() }
    func text(forIndex i: Int) -> String { texts[i] }
    func id(forIndex i: Int) -> Int32 { ids[i] }
    var dim: Int { _dim }
    var count: Int { _count }
    func topK(query: [Float], k: Int = 10) -> [(index: Int, score: Float)] {
        var res: [(Int, Float)] = []; res.reserveCapacity(min(k, count))
        let base = buffer.assumingMemoryBound(to: Float.self)
        for row in 0..<_count {
            var dot: Float = 0; vDSP_dotpr(base.advanced(by: row * _dim), 1, query, 1, &dot, vDSP_Length(_dim))
            res.append((row, dot))
        }
        res.sort { $0.1 > $1.1 }
        if res.count > k { res.removeSubrange(k..<res.count) }
        return res
    }

    /// Returns the embedding vector for a given lesson index.
    func vector(forIndex i: Int) -> [Float]? {
        guard i >= 0 && i < _count else { return nil }
        var out = [Float](repeating: 0, count: _dim)
        let base = buffer.assumingMemoryBound(to: Float.self)
        let rowPtr = base.advanced(by: i * _dim)
        for j in 0..<_dim { out[j] = rowPtr[j] }
        return out
    }

    /// Computes cosine (dot on normalized vectors) scores for all lessons for the provided query vector.
    func scores(forQuery query: [Float]) -> [Float] {
        precondition(query.count == _dim, "query dim mismatch")
        var scores = [Float](repeating: 0, count: _count)
        let base = buffer.assumingMemoryBound(to: Float.self)
        for row in 0..<_count {
            var dot: Float = 0
            vDSP_dotpr(base.advanced(by: row * _dim), 1, query, 1, &dot, vDSP_Length(_dim))
            scores[row] = dot
        }
        return scores
    }
}
