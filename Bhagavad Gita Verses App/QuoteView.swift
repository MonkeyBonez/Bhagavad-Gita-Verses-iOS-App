import SwiftUI

struct QuoteView: View {
    @State var viewModel: QuoteModel

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase

    let buttonClickPadding = 30.0

    init(dailyQuoteModel: QuoteModel = QuoteModel()) {
        self.viewModel = dailyQuoteModel
    }
    
    init(quote: String, author: String, chapter: Int, verse: Int) {
        viewModel = QuoteModel(quote: quote, author: author, chapter: chapter, verse: verse)
    }
    
    private func leftSideScreenTapSwipe() {
        viewModel.getPreviousVerse()
    }
    
    private func rightSideScreenTapSwipe() {
        viewModel.getNextVerse()
    }

    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : viewModel.bookmarked ? AppColors.lavender : AppColors.parchment
    }

    private var tapVerseChangeView: some View {
        HStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    leftSideScreenTapSwipe()
                }
            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 80)
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    rightSideScreenTapSwipe()
                }
        }
    }

    private var actionView: some View {
        return HStack(spacing: 52) {
            viewBookmarkedView
            shareButtonView
            bookmarkButtonView
        }
        .foregroundStyle(foregroundColor)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .safeAreaPadding(.bottom, 48-buttonClickPadding) // change to just padding?
    }

    @ViewBuilder
    private func actionIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 25)
            .padding(buttonClickPadding)
            .contentShape(Rectangle())
    }

    private var shareButtonView: some View {
        ShareLink(item: viewModel.shareText) {
            actionIcon(systemName: "square.and.arrow.up")
        }
    }

    private var bookmarkButtonView: some View {
        actionIcon(systemName: viewModel.bookmarked ? "bookmark.fill" : "bookmark")
            .onTapGesture { viewModel.bookmarkTapped() }
    }

    private var viewBookmarkedView: some View {
        actionIcon(systemName: viewModel.viewingBookmarked ? "book.pages.fill" : "book.pages")
            .onTapGesture { viewModel.viewingBookmarkedTapped() }
            .foregroundStyle(viewModel.hasBookmarks ? foregroundColor : .clear)
    }


    var textView: some View {
        VStack(spacing: 16) {
            Text(viewModel.quote)
                .font(.custom(Fonts.verseFontName, size: 30))
                .minimumScaleFactor(20/30)
                .multilineTextAlignment(.center)
            VStack(spacing: 0) {
                Text(viewModel.author)
                    .font(.custom(Fonts.verseFontName, size: 20))
                    .bold()
                Text("\(viewModel.chapter).\(viewModel.verse)")
            }
        }
        .foregroundStyle(foregroundColor)
        .padding(25)
        .padding(.bottom, 144)
    }

    var background: some View {
        colorScheme == .light ? viewModel.bookmarked ? AppColors.lavender.linearGradient : AppColors.parchment.linearGradient : AppColors.peacockBackground
    }

    var body: some View {
        ZStack {
            background
            textView
            tapVerseChangeView
            actionView
        }
        .gesture(DragGesture(minimumDistance: 15)
            .onEnded({$0.translation.width > 0 ? leftSideScreenTapSwipe() : rightSideScreenTapSwipe() })
        )
        .ignoresSafeArea()
        .onChange(of: scenePhase) { oldPhase , newPhase in
            viewModel.scenePhaseChange(from: oldPhase, to: newPhase)
            UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: false)
        }
    }
}

#Preview {
    let quote = "You have the right to perform your duty, but not to the fruits of your actions"
    let author = "Bhagavad Gita"
    let chapter = 2
    let verse = 47
    QuoteView(quote: quote, author: author, chapter: chapter, verse: verse)
}
