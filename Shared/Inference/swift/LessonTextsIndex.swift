import Foundation

public final class LessonTextsIndex {
    public struct Meta: Codable {
        public let count: Int
        public let dim: Int
        public let ids: [Int32]
        public let texts: [String]
        public let model: String
        public let source: String?
    }

    private let texts: [String]

    public init?(bundle: Bundle = .main) {
        func find(_ name: String, _ ext: String) -> URL? {
            // Try multiple likely subdirectories; Xcode may preserve or flatten
            let candidates = [
                "Inference/ModelAssets",
                "Shared/Inference/Retriever/Index",
                "Shared/Inference/retriever/Index",
                "inference/Retriever/Index",
                "inference/retriever/Index",
                nil
            ]
            for sub in candidates {
                if let sub = sub, let url = bundle.url(forResource: name, withExtension: ext, subdirectory: sub) {
                    return url
                }
                if sub == nil, let url = bundle.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
            return nil
        }
        guard let metaURL = find("lessons_meta", "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: metaURL)
            let meta = try JSONDecoder().decode(Meta.self, from: data)
            self.texts = meta.texts
        } catch {
            return nil
        }
    }

    public func text(forIndex i: Int) -> String { texts[i] }
    public var count: Int { texts.count }
}


