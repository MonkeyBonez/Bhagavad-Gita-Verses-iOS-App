import Foundation
import SwiftUI

struct EmotionNode: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let color: String?
    let children: [EmotionNode]?
}

struct EmotionWheelDocument: Codable {
    struct Schema: Codable {
        let id: String
        let label: String
        let color: String?
        let children: String
    }
    let name: String
    let version: String
    let license_note: String?
    let schema: Schema
    let data: [EmotionNode]
}

enum EmotionWheelLoadError: Error {
    case fileNotFound
    case decodeFailed
}

final class EmotionWheelLoader {
    static func load(fromBundle bundle: Bundle = .main) throws -> [EmotionNode] {
        let candidateNames = [
            "feelings_wheel",
            "Shared/Resources/feelings_wheel"
        ]
        var url: URL?
        for name in candidateNames {
            if let found = bundle.url(forResource: name, withExtension: "json") {
                url = found
                break
            }
        }
        guard let fileURL = url else { throw EmotionWheelLoadError.fileNotFound }
        let data = try Data(contentsOf: fileURL)
        let doc = try JSONDecoder().decode(EmotionWheelDocument.self, from: data)
        return doc.data
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if hexSanitized.count == 6 { hexSanitized = "FF" + hexSanitized }
        var int: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&int) else { return nil }
        let a = Double((int & 0xFF000000) >> 24) / 255.0
        let r = Double((int & 0x00FF0000) >> 16) / 255.0
        let g = Double((int & 0x0000FF00) >> 8) / 255.0
        let b = Double(int & 0x000000FF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}


