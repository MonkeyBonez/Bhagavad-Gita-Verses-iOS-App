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

    func quoteOfDayFor(date: Date) -> Verse {
        return quotes[getIndexFor(date: date)]
    }

    private func getIndexFor(date: Date) -> Int {
        return Calendar.current.component(.weekOfYear, from: date)
    }

    var quoteOfDay: Verse {
        quoteOfDayFor(date: Date())
    }
}
