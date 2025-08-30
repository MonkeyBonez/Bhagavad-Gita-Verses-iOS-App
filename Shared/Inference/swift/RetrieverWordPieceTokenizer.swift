import Foundation

final class RetrieverWordPieceTokenizer {
    private let tokenToId: [String: Int32]
    private let unkToken: String
    private let clsToken: String
    private let sepToken: String
    private let padToken: String
    private let unkId: Int32
    private let clsId: Int32
    private let sepId: Int32
    private let padId: Int32

    init?() {
        func url(_ name: String, _ ext: String) -> URL? {
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Shared/Inference/retriever/Tokenizer") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "inference/retriever/Tokenizer") { return u }
            if let u = Bundle.main.url(forResource: name, withExtension: ext) { return u }
            return nil
        }
        guard let vocabURL = url("vocab_retriever", "txt"), let specialURL = url("special_tokens_map_retriever", "json") else { return nil }
        var map: [String: Int32] = [:]
        do {
            let contents = try String(contentsOf: vocabURL, encoding: .utf8)
            var index: Int32 = 0
            contents.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).forEach { lineSub in
                let tok = String(lineSub)
                map[tok] = index
                index += 1
            }
        } catch { return nil }
        self.tokenToId = map
        var cls = "[CLS]", sep = "[SEP]", unk = "[UNK]", pad = "[PAD]"
        if let data = try? Data(contentsOf: specialURL), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let s = obj["cls_token"] as? String { cls = s }
            if let s = obj["sep_token"] as? String { sep = s }
            if let s = obj["unk_token"] as? String { unk = s }
            if let s = obj["pad_token"] as? String { pad = s }
        }
        self.clsToken = cls; self.sepToken = sep; self.unkToken = unk; self.padToken = pad
        self.unkId = map[unk] ?? 100; self.clsId = map[cls] ?? 101; self.sepId = map[sep] ?? 102; self.padId = map[pad] ?? 0
    }

    func encode(_ text: String, maxLen: Int = 128, prefix: String = "query: ") -> (ids: [Int32], mask: [Int32]) {
        let pre = prefix + text
        let tokens = basicTokenize(lowercased: pre.lowercased())
        var wordPieceIds: [Int32] = []
        for token in tokens {
            let pieces = wordPiece(token)
            if pieces.isEmpty { wordPieceIds.append(unkId) } else { for p in pieces { wordPieceIds.append(tokenToId[p] ?? unkId) } }
        }
        var ids: [Int32] = [clsId]; ids.append(contentsOf: wordPieceIds); ids.append(sepId)
        if ids.count > maxLen { ids = Array(ids.prefix(maxLen)); if let last = ids.last, last != sepId { ids[ids.count - 1] = sepId } }
        if ids.count < maxLen { ids.append(contentsOf: Array(repeating: padId, count: maxLen - ids.count)) }
        let mask: [Int32] = ids.map { $0 == padId ? 0 : 1 }
        return (ids, mask)
    }

    private func basicTokenize(lowercased text: String) -> [String] {
        var spaced: [Character] = []
        spaced.reserveCapacity(text.count * 2)
        for ch in text {
            if ch.isLetter || ch.isNumber { spaced.append(ch) }
            else if ch.isWhitespace { spaced.append(" ") }
            else { spaced.append(" "); spaced.append(ch); spaced.append(" ") }
        }
        return String(spaced).split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }
    private func wordPiece(_ token: String) -> [String] {
        let maxCharsPerWord = 100
        if token.count > maxCharsPerWord { return [unkToken] }
        var result: [String] = []
        var start = token.startIndex
        while start < token.endIndex {
            var end = token.endIndex
            var cur: String? = nil
            while start < end {
                var substr = String(token[start..<end])
                if start != token.startIndex { substr = "##" + substr }
                if tokenToId[substr] != nil { cur = substr; break }
                end = token.index(before: end)
            }
            if let piece = cur { result.append(piece); start = end } else { return [unkToken] }
        }
        return result
    }
}

import Foundation

/// Minimal WordPiece tokenizer compatible with BERT-style vocab.
/// Loads `vocab.txt` and `special_tokens_map.json` from the app bundle.
/// Produces `input_ids` and `attention_mask` (1=token, 0=pad), with [CLS] and [SEP] if available.
final class WordPieceTokenizer {
    private let tokenToId: [String: Int32]
    private let unkToken: String
    private let clsToken: String
    private let sepToken: String
    private let padToken: String
    private let unkId: Int32
    private let clsId: Int32
    private let sepId: Int32
    private let padId: Int32

    init?() {
        // Discover tokenizer files in bundle
        guard let vocabURL = WordPieceTokenizer.findResource(name: "vocab", ext: "txt", preferSubdir: "tokenizer"),
              let specialURL = WordPieceTokenizer.findResource(name: "special_tokens_map", ext: "json", preferSubdir: "tokenizer") else {
            print("WordPieceTokenizer: missing vocab.txt or special_tokens_map.json in bundle")
            return nil
        }

        // Load vocab.txt (one token per line)
        var map: [String: Int32] = [:]
        do {
            let contents = try String(contentsOf: vocabURL, encoding: .utf8)
            var index: Int32 = 0
            contents.split(whereSeparator: { $0 == "\n" || $0 == "\r" }).forEach { lineSub in
                let tok = String(lineSub)
                map[tok] = index
                index += 1
            }
        } catch {
            print("WordPieceTokenizer: failed reading vocab: \(error)")
            return nil
        }
        self.tokenToId = map

        // Load special tokens map
        var cls = "[CLS]", sep = "[SEP]", unk = "[UNK]", pad = "[PAD]"
        do {
            let data = try Data(contentsOf: specialURL)
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let s = obj["cls_token"] as? String { cls = s }
                if let s = obj["sep_token"] as? String { sep = s }
                if let s = obj["unk_token"] as? String { unk = s }
                if let s = obj["pad_token"] as? String { pad = s }
            }
        } catch {
            // Fallback to defaults above
        }
        self.clsToken = cls
        self.sepToken = sep
        self.unkToken = unk
        self.padToken = pad

        func id(for tok: String, fallback: Int32) -> Int32 {
            if let v = map[tok] { return v }
            return fallback
        }
        self.unkId = id(for: unk, fallback: 100)
        self.clsId = id(for: cls, fallback: 101)
        self.sepId = id(for: sep, fallback: 102)
        self.padId = id(for: pad, fallback: 0)
    }

    /// Encode a string with optional prefix (e.g., "query: "). Adds [CLS] [SEP], pads/truncates to maxLen.
    func encode(_ text: String, maxLen: Int = 128, prefix: String = "query: ") -> (ids: [Int32], mask: [Int32]) {
        let pre = prefix + text
        let tokens = basicTokenize(lowercased: pre.lowercased())
        var wordPieceIds: [Int32] = []
        for token in tokens {
            let pieces = wordPiece(token)
            if pieces.isEmpty {
                wordPieceIds.append(unkId)
            } else {
                for p in pieces {
                    if let id = tokenToId[p] {
                        wordPieceIds.append(id)
                    } else {
                        wordPieceIds.append(unkId)
                    }
                }
            }
        }

        // Add special tokens [CLS], [SEP]
        var ids: [Int32] = [clsId]
        ids.append(contentsOf: wordPieceIds)
        ids.append(sepId)

        // Truncate to maxLen
        if ids.count > maxLen {
            ids = Array(ids.prefix(maxLen))
            // Ensure last token is SEP if truncated
            if let last = ids.last, last != sepId { ids[ids.count - 1] = sepId }
        }
        // Pad
        if ids.count < maxLen {
            ids.append(contentsOf: Array(repeating: padId, count: maxLen - ids.count))
        }
        let mask: [Int32] = ids.map { $0 == padId ? 0 : 1 }
        return (ids, mask)
    }

    // MARK: - Helpers

    private static func findResource(name: String, ext: String, preferSubdir: String? = nil) -> URL? {
        // Try preferred subdirectory first
        if let sub = preferSubdir, let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: sub) {
            return url
        }
        // Then try anywhere in bundle
        if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        // Finally scan by filename match
        if let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
            return urls.first { $0.lastPathComponent == "\(name).\(ext)" }
        }
        return nil
    }

    private func basicTokenize(lowercased text: String) -> [String] {
        // Insert spaces around non-alphanumeric characters, then split on whitespace.
        var spaced: [Character] = []
        spaced.reserveCapacity(text.count * 2)
        for ch in text {
            if ch.isLetter || ch.isNumber {
                spaced.append(ch)
            } else if ch.isWhitespace { // keep single space
                spaced.append(" ")
            } else {
                spaced.append(" ")
                spaced.append(ch)
                spaced.append(" ")
            }
        }
        let s = String(spaced)
        return s.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }

    private func wordPiece(_ token: String) -> [String] {
        let maxCharsPerWord = 100
        if token.count > maxCharsPerWord { return [unkToken] }

        var result: [String] = []
        var start = token.startIndex
        while start < token.endIndex {
            var end = token.endIndex
            var cur: String? = nil
            while start < end {
                var substr = String(token[start..<end])
                if start != token.startIndex { substr = "##" + substr }
                if tokenToId[substr] != nil {
                    cur = substr
                    break
                }
                end = token.index(before: end)
            }
            if let piece = cur {
                result.append(piece)
                start = end
            } else {
                // no match
                return [unkToken]
            }
        }
        return result
    }
}


