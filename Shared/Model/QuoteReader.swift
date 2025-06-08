import Foundation

struct QuoteReader {
    let quotesFilePath = Bundle.main.path(forResource: "quotes-formatted", ofType: "json")
    var quotes: [Verse] = []

    init() {
        guard let quotes = FileReader.getVerses(filePath: quotesFilePath) else {
            return
        }
        self.quotes = quotes
    }
}
