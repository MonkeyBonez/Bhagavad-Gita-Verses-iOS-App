import Foundation

struct FileReader {
    static func getVerses(filePath: String?) -> [Verse]? {
        guard let filePath = filePath else {
            return nil
        }
        let fileUrl = URL(fileURLWithPath: filePath)
        guard let data = try? Data(contentsOf: fileUrl),
                let verses = try? JSONDecoder().decode([Verse].self, from: data) else {
            return nil
        }
        return verses
    }
}
