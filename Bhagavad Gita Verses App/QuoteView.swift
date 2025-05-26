import SwiftUI

struct QuoteView: View {
    @State var dailyQuoteModel: QuoteModel
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    init(dailyQuoteModel: QuoteModel = QuoteModel()) {
        self.dailyQuoteModel = dailyQuoteModel
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

    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.darkCharcoal : AppColors.parchment
    }

    private var verseChangeView: some View {
        HStack(spacing: 80) {
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

    private var actionView: some View { //TODO: Add bookmark functioanlity and boomark list view
        let buttonClickPadding = 30.0
        return HStack {
            ShareLink(item: dailyQuoteModel.shareText) {
                Image(systemName: "square.and.arrow.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 25)
                    .padding(buttonClickPadding)
                    .contentShape(Rectangle())
            }
        }
        .foregroundStyle(foregroundColor)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .safeAreaPadding(.bottom, 48-buttonClickPadding) // change to just padding?
    }


    var textView: some View {
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
        .foregroundStyle(foregroundColor)
        .padding(25)
        .padding(.bottom, 144)
    }

    var background: some View {
        colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.charcoalBackground
    }

    var body: some View {
        ZStack {
            background
            textView
            verseChangeView
            actionView
        }
        .ignoresSafeArea()
        .onChange(of: scenePhase) { oldPhase , newPhase in
            dailyQuoteModel.scenePhaseChange(from: oldPhase, to: newPhase)
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
