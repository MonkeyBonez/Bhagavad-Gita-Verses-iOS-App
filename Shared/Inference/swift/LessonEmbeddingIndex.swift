import Foundation
import Accelerate

final class LessonEmbeddingIndex {
    struct Meta: Codable { let count: Int; let dim: Int; let ids: [Int32]; let texts: [String]; let model: String; let source: String? }
    private let dim: Int
    private let count: Int
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
            dim = meta.dim; count = meta.count; ids = meta.ids; texts = meta.texts
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
    func topK(query: [Float], k: Int = 10) -> [(index: Int, score: Float)] {
        var res: [(Int, Float)] = []; res.reserveCapacity(min(k, count))
        let base = buffer.assumingMemoryBound(to: Float.self)
        for row in 0..<count {
            var dot: Float = 0; vDSP_dotpr(base.advanced(by: row * dim), 1, query, 1, &dot, vDSP_Length(dim))
            res.append((row, dot))
        }
        res.sort { $0.1 > $1.1 }
        if res.count > k { res.removeSubrange(k..<res.count) }
        return res
    }
}

import Foundation
import Accelerate

/// Loads lesson embeddings and supports cosine search (dot product on normalized vectors).
final class EmbeddingIndex {
    struct Meta: Codable {
        let count: Int
        let dim: Int
        let ids: [Int32]
        let texts: [String]
        let model: String
        let source: String?
    }

    private let dim: Int
    private let count: Int
    private let ids: [Int32]
    private let texts: [String]
    private let buffer: UnsafeMutableRawPointer
    private let byteCount: Int

    init?(bundle: Bundle = .main) {
        // Locate resources whether Xcode flattens or preserves folder structure
        func find(_ name: String, _ ext: String) -> URL? {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Inference/ModelAssets") {
                return url
            }
            return bundle.url(forResource: name, withExtension: ext)
        }
        guard let metaURL = find("lessons_meta", "json"),
              let binURL = find("lessons_f32", "bin") else {
            print("EmbeddingIndex: missing lessons_meta.json or lessons_f32.bin in bundle")
            return nil
        }

        // Load meta
        do {
            let data = try Data(contentsOf: metaURL)
            let meta = try JSONDecoder().decode(Meta.self, from: data)
            self.dim = meta.dim
            self.count = meta.count
            self.ids = meta.ids
            self.texts = meta.texts
        } catch {
            print("EmbeddingIndex: failed to decode meta: \(error)")
            return nil
        }

        // Map embeddings
        do {
            let handle = try FileHandle(forReadingFrom: binURL)
            let fileSize = try handle.seekToEnd()
            try handle.seek(toOffset: 0)
            self.byteCount = Int(fileSize)
            // Allocate and read into memory (simple approach; switch to mmap if needed)
            self.buffer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<Float>.alignment)
            let data = try handle.readToEnd() ?? Data()
            data.copyBytes(to: buffer.assumingMemoryBound(to: UInt8.self), count: data.count)
            try handle.close()
        } catch {
            print("EmbeddingIndex: failed to read bin: \(error)")
            return nil
        }
    }

    deinit {
        buffer.deallocate()
    }

    func text(forIndex i: Int) -> String { texts[i] }
    func id(forIndex i: Int) -> Int32 { ids[i] }

    /// Returns top-k indices and scores sorted desc.
    func topK(query: [Float], k: Int = 10) -> [(index: Int, score: Float)] {
        precondition(query.count == dim, "query dim mismatch")
        var results: [(Int, Float)] = []
        results.reserveCapacity(min(k, count))
        let basePtr = buffer.assumingMemoryBound(to: Float.self)
        for row in 0..<count {
            let rowPtr = basePtr.advanced(by: row * dim)
            var dot: Float = 0
            vDSP_dotpr(rowPtr, 1, query, 1, &dot, vDSP_Length(dim))
            results.append((row, dot))
        }
        results.sort { $0.1 > $1.1 }
        if results.count > k { results.removeSubrange(k..<results.count) }
        return results
    }
}


