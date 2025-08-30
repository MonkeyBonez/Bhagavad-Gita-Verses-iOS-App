import Foundation

public struct LessonResult {
    public let id: Int32
    public let text: String
    public let cosine: Float
    public let ce: Float?
}

public final class LessonSearchHelper {
    private let tokenizer: RetrieverWordPieceTokenizer
    private let embedder: E5RetrieverEmbedder
    private let index: LessonEmbeddingIndex
    private let pairTokenizer: PairWordPieceTokenizer
    private let reranker: MiniLMReranker

    public init?() {
        guard let tok = RetrieverWordPieceTokenizer(), let emb = E5RetrieverEmbedder(), let idx = LessonEmbeddingIndex(), let pt = PairWordPieceTokenizer(), let rr = MiniLMReranker() else { return nil }
        tokenizer = tok; embedder = emb; index = idx; pairTokenizer = pt; reranker = rr
    }

    public func search(text: String, topK: Int = 10, retrieveTopK: Int = 50, doRerank: Bool = true) -> [LessonResult] {
        let enc = tokenizer.encode(text, maxLen: 128, prefix: "query: ")
        guard let q = embedder.embed(inputIds: enc.ids, attentionMask: enc.mask) else { return [] }
        let retrN = max(topK, retrieveTopK)
        var hits = index.topK(query: q, k: retrN).map { (row, cos) in (row, cos, nil as Float?) }
        if doRerank {
            let passages = hits.map { index.text(forIndex: $0.0) }
            let ceScores = reranker.scoreBatch(query: text, passages: passages, tokenizer: pairTokenizer, maxLen: 160, maxQuery: 48)
            for i in 0..<hits.count {
                let s = ceScores[i]
                if s.isFinite && abs(s) < 1e6 {
                    hits[i].2 = s
                    print("CE[\(i)] = \(s)")
                } else {
                    hits[i].2 = nil
                    print("CE[\(i)] = nil")
                }
            }
            hits.sort { ($0.2 ?? -Float.greatestFiniteMagnitude) > ($1.2 ?? -Float.greatestFiniteMagnitude) }
        }
        let trimmed = hits.prefix(topK)
        return trimmed.map { t in LessonResult(id: index.id(forIndex: t.0), text: index.text(forIndex: t.0), cosine: t.1, ce: t.2) }
    }
}
