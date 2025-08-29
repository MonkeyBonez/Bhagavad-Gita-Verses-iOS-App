import SwiftUI
import UIKit

struct VerseView: View {
    @State var viewModel: QuoteModel
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State var screenWidth = CGFloat(0)
    @State var screenHeight = CGFloat(0)
    @State var footerVerseInfo: Verse
    
    // Paging state
    @State private var dataSource: [Int] = [] // global verse indices
    @State private var scrollPosition: Int?
    @State private var selectedGlobalIndex: Int = 0
    @State private var introOpacity: CGFloat = 0.0
    @State private var isIntroAnimating: Bool = false
    
    let buttonClickPadding = 30.0
    private let fadeThreshold: CGFloat = 0.4
    
    // Cubic easeInOut mapping for 0...1 → 0...1
    private func easeInOut01(_ t: CGFloat) -> CGFloat {
        let x = max(0, min(1, t))
        return (3 * x * x) - (2 * x * x * x)
    }
    
    init(dailyQuoteModel: QuoteModel = QuoteModel()) {
        self._viewModel = State(initialValue: dailyQuoteModel)
        self._footerVerseInfo = State(initialValue: dailyQuoteModel.quote)
        self._selectedGlobalIndex = State(initialValue: dailyQuoteModel.currentGlobalIndex)
        self._scrollPosition = State(initialValue: dailyQuoteModel.currentGlobalIndex)
        self._dataSource = State(initialValue: [])
    }
    
    init(quote: String, author: String, chapter: Int, verse: Int) {
        let quoteModel = QuoteModel(quote: quote, author: author, chapter: chapter, verse: verse)
        self._viewModel = State(initialValue: quoteModel)
        self._footerVerseInfo = State(initialValue: quoteModel.quote)
        self._selectedGlobalIndex = State(initialValue: quoteModel.currentGlobalIndex)
        self._scrollPosition = State(initialValue: quoteModel.currentGlobalIndex)
        self._dataSource = State(initialValue: [])
    }
    
    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : viewModel.bookmarked ? AppColors.lavender : AppColors.parchment
    }
    
    private func foregroundColorForQuote(bookmarked: Bool) -> Color {
        colorScheme == .light ? AppColors.lightPeacock : bookmarked ? AppColors.lavender : AppColors.parchment
    }
    
    private var footerActionView: some View {
        return HStack() {
            shareButtonView
            Spacer()
            bookmarkButtonView
        }
        .foregroundStyle(foregroundColor)
        .frame(maxHeight: .infinity, alignment: .bottom)
//        .safeAreaPadding(.bottom, 48-buttonClickPadding)
    }

    private var headerActionView: some View {
        HStack(spacing: 0) {
            // Placeholder for future top-left button
            Spacer()
            viewBookmarkedView
        }
        .foregroundStyle(foregroundColor)
    }
    
    @ViewBuilder
    private func actionIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 26)
            .padding(buttonClickPadding)
            .contentShape(Rectangle())
    }
    
    private var shareButtonView: some View {
        AnimatedTap(content: {
            ShareLink(item: viewModel.shareText) {
                actionIcon(systemName: "square.and.arrow.up")
            }
        }, onTap: { })
    }
    
    private var bookmarkButtonView: some View {
        AnimatedTap(content: {
            actionIcon(systemName: viewModel.bookmarked ? "bookmark.fill" : "bookmark")
        }, onTap: {
            let wasBookmarked = viewModel.bookmarked
            let wasViewingBookmarked = viewModel.viewingBookmarked
            viewModel.bookmarkTapped()
            if !wasBookmarked {
                // Added a bookmark; skip soft haptic if this is the very first bookmark
                let bookmarkCount = viewModel.bookmarkedGlobalIndices.count
                if bookmarkCount > 1 {
                    triggerSoftBookmarkHaptic()
                }
                else{
                    triggerStrongBookmarkHaptic()
                }
            } else if wasViewingBookmarked {
                viewModel.viewingBookmarkedDisable()
                rebuildDataSource()
                selectedGlobalIndex = viewModel.currentGlobalIndex
                scrollPosition = selectedGlobalIndex
            }
        })
    }
    
    private var viewBookmarkedView: some View {
        AnimatedTap(content: {
            actionIcon(systemName: viewModel.viewingBookmarked ? "book.pages.fill" : "book.pages")
                .foregroundStyle(viewModel.hasBookmarks ? foregroundColor : .clear)
                .symbolEffect(.bounce, value: viewModel.viewBookmarkAddIndicator)
        }, onTap: {
            toggleBookmarkedOnly()
        })
    }
    
    private func toggleBookmarkedOnly() {
        viewModel.viewingBookmarkedTapped()
        rebuildDataSource()
        // Ensure the current selected index is visible in the new dataSource
        if viewModel.viewingBookmarked {
            // Jump to the nearest bookmarked to the current verse
            let current = viewModel.currentGlobalIndex
            if let nearest = dataSource.min(by: { abs($0 - current) < abs($1 - current) }) {
                selectedGlobalIndex = nearest
                scrollPosition = nearest
                viewModel.setCurrentByGlobalIndex(nearest)
                setFooterQuoteAfterQuoteChange()
            } else if let first = dataSource.first {
                selectedGlobalIndex = first
                scrollPosition = first
                viewModel.setCurrentByGlobalIndex(first)
                setFooterQuoteAfterQuoteChange()
            }
        }
    }

    private func setFooterQuoteAfterQuoteChange() {
        footerVerseInfo = viewModel.quote
    }

    private func triggerSoftBookmarkHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.5)
    }

    private func triggerStrongBookmarkHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 0.6)
    }

    // Reusable micro-animation wrapper for tap interactions
    private struct AnimatedTap<Content: View>: View {
        let content: () -> Content
        let onTap: () -> Void
        @State private var scale: CGFloat = 1.0
        var body: some View {
            content()
                .scaleEffect(scale)
                .simultaneousGesture(TapGesture().onEnded {
                    scale = 0.9
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                        scale = 1.0
                    }
                    onTap()
                })
        }
    }
    
    private func rebuildDataSource() {
        if viewModel.viewingBookmarked {
            dataSource = viewModel.bookmarkedGlobalIndices
        } else {
            dataSource = Array(0..<viewModel.totalVerseCount)
        }
    }
    
    // Display indices equals the data source (no transient items)
    private func displayIndices() -> [Int] { dataSource }
    
    private func goToPrevious() {
        guard let currentIdx = dataSource.firstIndex(of: selectedGlobalIndex), currentIdx > 0 else { return }
        let target = dataSource[currentIdx - 1]
        scrollPosition = target
    }
    
    private func goToNext() {
        guard let currentIdx = dataSource.firstIndex(of: selectedGlobalIndex), currentIdx + 1 < dataSource.count else { return }
        let target = dataSource[currentIdx + 1]
        scrollPosition = target
    }
    
    private func quoteFooterView(quote: Verse) -> some View {
        VStack(spacing: 0) {
            Text(viewModel.author)
                .font(.custom(Fonts.verseFontName, size: 20))
                .bold()
            Text("\(quote.chapterNumber).\(quote.verseNumber)")
        }
    }
    
    private func quotePage(globalIndex: Int) -> some View {
        let verse = viewModel.verse(atGlobalIndex: globalIndex)
        return GeometryReader { geo in
            let frame = geo.frame(in: .named("scroll"))
            let centerX = screenWidth / 2
            let dx = frame.midX - centerX
            let distanceFromCenter = abs(dx) / max(screenWidth, 1)
            let normalized = min(distanceFromCenter / fadeThreshold, 1)
            let opacity = max(0, 1.0 - easeInOut01(normalized))
            VStack(spacing: 16) {
                Text(verse.text)
                    .font(.custom(Fonts.verseFontName, size: 30))
                    .minimumScaleFactor(20/30)
                    .multilineTextAlignment(.center)
                quoteFooterView(quote: verse)
                    .offset(x: -dx)
                    .opacity(opacity)
            }
            .foregroundStyle(foregroundColorForQuote(bookmarked: verse.bookmarked))
            .padding(25)
            .padding(.bottom, 144) // leave toolbar area free
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerRelativeFrame(.horizontal)
        .id(globalIndex)
    }
    
    var background: some View {
        colorScheme == .light ? viewModel.bookmarked ? AppColors.lavender.linearGradient : AppColors.parchment.linearGradient : AppColors.peacockBackground
    }
    
    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            
            // Wrap the horizontal scroll in a full-screen content shape to capture drags anywhere
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(displayIndices(), id: \.self) { index in
                        quotePage(globalIndex: index)
                    }
                }
                .scrollTargetLayout()
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if value.location.x < screenWidth / 2 {
                            goToPrevious()
                        } else {
                            goToNext()
                        }
                    }
            )
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .coordinateSpace(.named("scroll"))
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .opacity(introOpacity)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            screenWidth = geometry.size.width
                            screenHeight = geometry.size.height
                            rebuildDataSource()
                        }
                }
            )
            .onChange(of: scrollPosition) { _, newValue in
                if isIntroAnimating { return }
                if let newValue = newValue {
                    selectedGlobalIndex = newValue
                    viewModel.setCurrentByGlobalIndex(newValue)
                    setFooterQuoteAfterQuoteChange()
                }
            }
            VStack {
                headerActionView
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 30)
            .ignoresSafeArea()
            VStack {
                Spacer()
                footerActionView
                    .padding(.horizontal, 20)
            }
            .padding(.bottom, 11)
            .ignoresSafeArea()
            
        }
        .allowsHitTesting(!isIntroAnimating)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            viewModel.scenePhaseChange(from: oldPhase, to: newPhase)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.dismiss(animated: false)
            }
        }
        // Respond to external mode changes (e.g., deeplink resets)
        .onChange(of: viewModel.bookmarkedOnlyMode) { _, _ in
            if isIntroAnimating { return }
            rebuildDataSource()
            selectedGlobalIndex = viewModel.currentGlobalIndex
            scrollPosition = selectedGlobalIndex
        }
        // Respond to external verse changes (e.g., deeplink to quote of the day)
        .onChange(of: viewModel.quote) { _, _ in
            if isIntroAnimating { return }
            selectedGlobalIndex = viewModel.currentGlobalIndex
            scrollPosition = selectedGlobalIndex
        }
        // Run intro animation when we arrive at verse-of-day via deeplink or cold start
        .onChange(of: viewModel.animateFromEndToken) { _, _ in
            runIntroAnimationToCurrent()
        }
        .onAppear {
            rebuildDataSource()
            selectedGlobalIndex = viewModel.currentGlobalIndex
            // Trigger intro after first layout pass
            DispatchQueue.main.async {
                runIntroAnimationToCurrent()
            }
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

// MARK: - Intro animation
extension VerseView {
    private func runIntroAnimationToCurrent() {
        guard !dataSource.isEmpty, !isIntroAnimating else { return }
        let current = viewModel.currentGlobalIndex
        // Find current's position within the dataSource; if absent, use nearest by distance
        let currentPos: Int = dataSource.firstIndex(of: current)
            ?? dataSource.enumerated().min(by: { abs($0.element - current) < abs($1.element - current) })?.offset
            ?? 0
        // Move 5 pages ahead within dataSource bounds
        let targetPos = min(currentPos + 5, dataSource.count - 1)
        let startIndex = dataSource[targetPos]
        guard startIndex != current else { return }
        // Disable interactions and set initial opacity (opacity currently unused)
        isIntroAnimating = true
        introOpacity = 0.0
        let duration: Double = 0.8
        let extraOpacityDuration = 0.1
        // Phase 1: perform the jump without animation after layout
        DispatchQueue.main.async {
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                scrollPosition = startIndex
            }
            // Phase 2: animate to the current verse after a short delay so the jump is committed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(duration: duration, bounce: 0.15)) {
                    scrollPosition = current
                }
                withAnimation(.easeInOut(duration: duration + extraOpacityDuration)) {
                    introOpacity = 1.0
                }
                // Finalize after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + extraOpacityDuration) {
                    selectedGlobalIndex = current
                    viewModel.setCurrentByGlobalIndex(current)
                    setFooterQuoteAfterQuoteChange()
                    isIntroAnimating = false
                }
            }
        }
    }
}





