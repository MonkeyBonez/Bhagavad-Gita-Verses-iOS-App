import SwiftUI

struct QuoteView: View {
    @State var dailyQuoteModel: QuoteModel
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        dailyQuoteModel = QuoteModel()
    }
    
    init(quote: String, author: String, chapter: String, verse: String) {
        dailyQuoteModel = QuoteModel(quote: quote, author: author, chapter: chapter, verse: verse)
    }
    
    private func leftSideScreenTap() {
        dailyQuoteModel.getPreviousVerse()
    }
    
    private func rightSideScreenTap() {
        dailyQuoteModel.getNextVerse()
    }
    
    var interactionArea: some View {
        HStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    leftSideScreenTap()
                }
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    rightSideScreenTap()
                }
        }
    }
    
    var body: some View {
        ZStack {
            if colorScheme == .light {
                AppColors.parchment
            } else {
                AppColors.charcoalBackground
            }
            VStack(spacing: 16) {
                Text(dailyQuoteModel.quote)
                    .font(.custom(Fonts.verseFontName, size: 30))
                    .minimumScaleFactor(20/30)
                    .multilineTextAlignment(.center)
                VStack(spacing: 0) {
                    Text(dailyQuoteModel.author)
                        .font(.custom(Fonts.verseFontName, size: 20))
                        .bold()
                    Text("\(dailyQuoteModel.chapter).\(dailyQuoteModel.verse)")
                }
            }
            .foregroundStyle(colorScheme == .light ? AppColors.darkCharcoal : AppColors.parchment)
            .padding(25)
            .padding(.bottom, 144)
            interactionArea
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _ , newPhase in
            if newPhase == .active {
                dailyQuoteModel.viewLoaded()
            }
        }
    }
}

#Preview {
    let quote = "You have the right to perform your duty, but not to the fruits of your actions"
    let author = "Bhagavad Gita"
    let chapter = "2"
    let verse = "47"
    QuoteView(quote: quote, author: author, chapter: chapter, verse: verse)
}
