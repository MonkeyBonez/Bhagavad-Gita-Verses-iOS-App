import SwiftUI

struct VerseView: View {
    @State var viewModel: QuoteModel
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State var showRightGuidance = false
    @State var showLeftGuidance = false
    @State var validInteraction = false
    @State var swipeXOffset = CGFloat(0)
    @State var screenWidth = CGFloat(0)
    @State var currQuoteHeight = CGFloat(0)
    
    let buttonClickPadding = 30.0
    
    init(dailyQuoteModel: QuoteModel = QuoteModel()) {
        self.viewModel = dailyQuoteModel
    }
    
    init(quote: String, author: String, chapter: Int, verse: Int) {
        viewModel = QuoteModel(quote: quote, author: author, chapter: chapter, verse: verse)
    }
    
    private func backwardsTapSwipe() {
        validInteraction = true
        viewModel.getPreviousVerse()
        validInteraction = false
    }
    
    private func forwardsTapSwipe() {
        validInteraction = true
        viewModel.getNextVerse()
        validInteraction = false
    }
    
    private func flashGuidance() {
        guard !showLeftGuidance, !showRightGuidance else {
            return
        }
        showLeftGuidance = true
        showRightGuidance = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showLeftGuidance = false
            showRightGuidance = false
        }
    }
    
    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : viewModel.bookmarked ? AppColors.lavender : AppColors.parchment
    }
    
    private func foregroundColorForQuote(bookmarked: Bool) -> Color {
        colorScheme == .light ? AppColors.lightPeacock : bookmarked ? AppColors.lavender : AppColors.parchment
    }
    
    private var tapVerseChangeView: some View {
        HStack(spacing: 0) {
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    backwardsTapSwipe()
                }
            Rectangle()
                .foregroundStyle(.clear)
                .frame(width: 80)
                .contentShape(Rectangle())
                .onTapGesture {
                    flashGuidance()
                }
            Rectangle()
                .foregroundStyle(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    forwardsTapSwipe()
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
            .symbolEffect(.bounce, value: viewModel.viewBookmarkAddIndicator)
    }
    
    var versesView: some View {
        HStack {
            if let prevQuote = viewModel.prevQuote {
                quoteView(quote: prevQuote)
                    .frame(width: screenWidth)
            }
            quoteView(quote: viewModel.quote)
                .frame(width: screenWidth)
            if let nextQuote = viewModel.nextQuote {
                quoteView(quote: nextQuote)
                    .frame(width: screenWidth)
            }
        }
        .offset(x: swipeXOffset)
    }
    
    var dontHideGuidance: Bool {
        swipeXOffset.isZero //TODO: smooth animation instead or remove guidance
    }
    
    @ViewBuilder
    func quoteView(quote: Verse) -> some View {
        VStack(spacing: 16) {
            Text(quote.text)
                .font(.custom(Fonts.verseFontName, size: 30))
                .minimumScaleFactor(20/30)
                .multilineTextAlignment(.center)
            VStack(spacing: 0) {
                Text(viewModel.author)
                    .font(.custom(Fonts.verseFontName, size: 20))
                    .bold()
                HStack() {
                    if dontHideGuidance {
                        guidanceView(systemImageName: "chevron.left", value: showLeftGuidance)
                        Spacer()
                    }
                    Text("\(quote.chapterNumber).\(quote.verseNumber)")
                    if dontHideGuidance {
                        Spacer()
                        guidanceView(systemImageName: "chevron.right", value: showRightGuidance)
                    }
                    
                }
                .padding(.horizontal, 16)
            }
        }
        .foregroundStyle(foregroundColorForQuote(bookmarked: quote.bookmarked))
        .padding(25)
        .padding(.bottom, 144)
    }
    
    func guidanceView(systemImageName: String, value: Bool) -> some View {
        Image(systemName: systemImageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 24)
            .offset(y: -12)
            .opacity(value ? 1: 0)
            .animation(.easeInOut(duration: 0.5), value: value)
    }
    
    var background: some View {
        colorScheme == .light ? viewModel.bookmarked ? AppColors.lavender.linearGradient : AppColors.parchment.linearGradient : AppColors.peacockBackground
    }
    
    var body: some View {
        ZStack {
            background
            versesView
            tapVerseChangeView
            actionView
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged({ gesture in
                swipeXOffset = gesture.translation.width
            })
            .onEnded({ gesture in
                respondToSwipeEnded(swipeAmount: gesture.translation.width, swipeVelocity: gesture.velocity.width)
                resetQuoteToCenter()
            })
        )
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { screenWidth = geometry.size.width}
            }
        )
        .ignoresSafeArea()
        .onChange(of: scenePhase) { oldPhase , newPhase in
            swipeXOffset = 0
            viewModel.scenePhaseChange(from: oldPhase, to: newPhase)
            UIApplication.shared.windows.first?.rootViewController?.dismiss(animated: false)
        }
        .onAppear {
            flashGuidance()
        }
    }
    
    private func respondToSwipeEnded(swipeAmount: CGFloat, swipeVelocity: CGFloat) {
        let minimumSwipeScreenRatioThresholdNoVelocity = 0.4
        let minimumSwipeScreenRatioThresholdHighVelocity = 0.25
        let minimumThresholdHighVelocity = 1000.0
        let swipeAmountToScreenWidth = swipeAmount/screenWidth
        if isSwipe(minimumSwipeScreenRatioThresholdNoVelocity: abs(minimumSwipeScreenRatioThresholdNoVelocity),
                   minimumSwipeScreenRatioThresholdHighVelocity: abs(minimumSwipeScreenRatioThresholdHighVelocity),
                   minimumThresholdHighVelocity: abs(minimumThresholdHighVelocity),
                   swipeAmountToScreenWidth: abs(swipeAmountToScreenWidth),
                   swipeVelocity: abs(swipeVelocity),
                   swipeAmount: abs(swipeAmount)) {
            if swipeAmount > 0 {
                backwardsSwipe(swipeAmount: swipeAmount)
            }
            else {
                forwardsSwipe(swipeAmount: swipeAmount)
            }
            
        }
    }
    
    //Uses abs values
    private func isSwipe(minimumSwipeScreenRatioThresholdNoVelocity: CGFloat, minimumSwipeScreenRatioThresholdHighVelocity: CGFloat, minimumThresholdHighVelocity: CGFloat, swipeAmountToScreenWidth: CGFloat, swipeVelocity: CGFloat, swipeAmount: CGFloat) -> Bool{
        if swipeAmountToScreenWidth > minimumSwipeScreenRatioThresholdHighVelocity {
            if swipeAmountToScreenWidth > minimumSwipeScreenRatioThresholdNoVelocity || swipeVelocity > minimumThresholdHighVelocity {
                return true
            }
        }
        return false
    }
    
    private func backwardsSwipe(swipeAmount: CGFloat) {
        swipeXOffset = -screenWidth + swipeAmount
        backwardsTapSwipe()
    }
    
    private func forwardsSwipe(swipeAmount: CGFloat) {
        swipeXOffset = screenWidth + swipeAmount
        forwardsTapSwipe()
    }
    
    //TODO: Fine tune
    func resetQuoteToCenter() {
        withAnimation(.snappy) {
            swipeXOffset = 0
        }
    }
    
}

#Preview {
    let quote = "You have the right to perform your duty, but not to the fruits of your actions"
    let author = "Bhagavad Gita"
    let chapter = 2
    let verse = 47
    VerseView(quote: quote, author: author, chapter: chapter, verse: verse)
}
