import Foundation

final class PairWordPieceTokenizer {
    private let tokenToId: [String: Int32]
    private let clsId: Int32
    private let sepId: Int32
    private let padId: Int32
    private let unkId: Int32

    init?() {
        func url(_ name: String, _ ext: String) -> URL? {
            // Prefer cross-encoder tokenizer first
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Shared/Inference/cross-encoder/Tokenizer") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "inference/cross-encoder/Tokenizer") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Shared/Inference/retriever/Tokenizer") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "inference/retriever/Tokenizer") { return u }
            return Bundle.main.url(forResource: name, withExtension: ext)
        }
        guard let vocabURL = url("vocab_ce", "txt"), let specialURL = url("special_tokens_map_ce", "json") else { return nil }
        var map: [String: Int32] = [:]
        do {
            let contents = try String(contentsOf: vocabURL, encoding: .utf8)
            var idx: Int32 = 0
            contents.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).forEach { line in map[String(line)] = idx; idx += 1 }
        } catch { return nil }
        tokenToId = map
        var cls = "[CLS]", sep = "[SEP]", pad = "[PAD]", unk = "[UNK]"
        if let data = try? Data(contentsOf: specialURL), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = obj["cls_token"] as? String { cls = s }
            if let s = obj["sep_token"] as? String { sep = s }
            if let s = obj["pad_token"] as? String { pad = s }
            if let s = obj["unk_token"] as? String { unk = s }
        }
        clsId = map[cls] ?? 101; sepId = map[sep] ?? 102; padId = map[pad] ?? 0; unkId = map[unk] ?? 100
    }

    func encodePair(query: String, passage: String, maxLen: Int = 160, maxQuery: Int = 48) -> (ids: [Int32], mask: [Int32], types: [Int32]) {
        func basic(_ s: String) -> [String] {
            var out: [Character] = []
            for ch in s.lowercased() { if ch.isLetter || ch.isNumber { out.append(ch) } else if ch.isWhitespace { out.append(" ") } else { out.append(" "); out.append(ch); out.append(" ") } }
            return String(out).split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        }
        func wp(_ tok: String) -> [String] {
            if tok.count > 100 { return ["[UNK]"] }
            var res: [String] = []; var start = tok.startIndex
            while start < tok.endIndex {
                var end = tok.endIndex; var cur: String? = nil
                while start < end { var sub = String(tok[start..<end]); if start != tok.startIndex { sub = "##" + sub }; if tokenToId[sub] != nil { cur = sub; break }; end = tok.index(before: end) }
                if let piece = cur { res.append(piece); start = end } else { return ["[UNK]"] }
            }
            return res
        }
        var qIds: [Int32] = []; for t in basic(query) { for p in wp(t) { qIds.append(tokenToId[p] ?? unkId) } }
        var pIds: [Int32] = []; for t in basic(passage) { for p in wp(t) { pIds.append(tokenToId[p] ?? unkId) } }
        if qIds.count > maxQuery { qIds = Array(qIds.prefix(maxQuery)) }
        var ids: [Int32] = [clsId]; ids.append(contentsOf: qIds); ids.append(sepId)
        let typesQ = [Int32](repeating: 0, count: ids.count)
        let remaining = max(0, maxLen - (ids.count + 1))
        if pIds.count > remaining { pIds = Array(pIds.prefix(remaining)) }
        ids.append(contentsOf: pIds); ids.append(sepId)
        var types: [Int32] = typesQ + [Int32](repeating: 1, count: ids.count - typesQ.count)
        var mask: [Int32] = [Int32](repeating: 1, count: ids.count)
        if ids.count < maxLen {
            let padCount = maxLen - ids.count
            ids.append(contentsOf: [Int32](repeating: padId, count: padCount))
            mask.append(contentsOf: [Int32](repeating: 0, count: padCount))
            types.append(contentsOf: [Int32](repeating: 0, count: padCount))
        }
        // Ensure exact lengths (some safety)
        if ids.count > maxLen { ids = Array(ids.prefix(maxLen)) }
        if mask.count > maxLen { mask = Array(mask.prefix(maxLen)) }
        if types.count > maxLen { types = Array(types.prefix(maxLen)) }
        return (ids, mask, types)
    }
}
