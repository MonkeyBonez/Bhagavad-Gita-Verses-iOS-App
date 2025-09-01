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
    // Guidance sheet state
    @State private var showGuidanceSheet: Bool = false
    @State private var showingEmotionWheel: Bool = false
    @State private var guidanceQuery: String = ""
    @State private var guidanceTopK: Int = 3
    @State private var guidanceRetrieveTopK: Int = 10
    @State private var guidanceResults: [LessonResult] = []
    @State private var isSearchingGuidance: Bool = false
    @State private var guidanceError: String? = nil
    @State private var searchHelper: LessonSearchHelper? = nil
    @State private var unitsIndex: LessonUnitsIndex? = LessonUnitsIndex()
    
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
            bookmarkButtonView
            Spacer()
            shareButtonView
        }
        .foregroundStyle(foregroundColor)
        .frame(maxHeight: .infinity, alignment: .bottom)
//        .safeAreaPadding(.bottom, 48-buttonClickPadding)
    }

    private var headerActionView: some View {
        HStack(spacing: 0) {
            viewBookmarkedView
            Spacer()
            guidanceButtonView
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

    private var guidanceButtonView: some View {
        Menu {
            Section("Gita Guidance") {
                Button {
                    showGuidanceSheet = true
                } label: {
                    Label("Describe circumstance", systemImage: "pencil")
                }
                Button {
//                    showGuidanceSheet = true
                    showingEmotionWheel = true
                } label: {
                    Label("Pick Emotion", systemImage: "smallcircle.circle")
                }
                // Future options will be added here
            }
        } label: {
            actionIcon(systemName: "sparkles")
        }
        .fullScreenCover(isPresented: $showGuidanceSheet) {
            GuidanceSheetView(
                query: $guidanceQuery,
                topK: $guidanceTopK,
                retrieveTopK: $guidanceRetrieveTopK,
                isSearching: isSearchingGuidance,
                errorText: guidanceError,
                results: guidanceResults,
                onSearch: { runGuidanceSearch() },
                onClose: { showGuidanceSheet = false },
                isBookmarked: viewModel.bookmarked
            )
        }
        .fullScreenCover(isPresented: $showingEmotionWheel) {
            EmotionWheelContainerView(isBookmarked: viewModel.bookmarked, onQuery: { query in
                showingEmotionWheel = false
                runGuidanceSearch(text: query)
            })
        }
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
            // Do not dismiss presentations while guidance covers are shown
            if showGuidanceSheet || showingEmotionWheel { return }
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
            let target = viewModel.currentGlobalIndex
            animateTowardsVerse(globalIndex: target)
        }
        .onAppear {
            rebuildDataSource()
            selectedGlobalIndex = viewModel.currentGlobalIndex
            // Trigger intro after first layout pass
            DispatchQueue.main.async {
                let target = viewModel.currentGlobalIndex
                animateTowardsVerse(globalIndex: target)
            }
        }
        .onAppear { showingEmotionWheel = false }
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
    // Animate away from the current verse by paging backwards
    func animateAwayFromCurrentBackwards(pages: Int = 7) {
        guard !dataSource.isEmpty, !isIntroAnimating else { return }
        // Use the currently displayed index to avoid mismatch with view model on first call
        let currentDisplayed = selectedGlobalIndex
        guard let currentPos = dataSource.firstIndex(of: currentDisplayed) else { return }
        let targetPos = max(currentPos - max(1, pages), 0)
        let backwardIndex = dataSource[targetPos]
        guard backwardIndex != currentDisplayed else { return }
        isIntroAnimating = true
        let duration: Double = 0.8
        // Start visible, end invisible
        introOpacity = 1.0
        // Separate transactions to ensure scroll commits on first call
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: duration)) {
                introOpacity = 0.0
            }
            var txn = Transaction()
            txn.animation = .easeIn(duration: duration)
            withTransaction(txn) {
                scrollPosition = backwardIndex
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                // Sync model state to the new position and re-enable interactions
                self.selectedGlobalIndex = backwardIndex
                self.viewModel.setCurrentByGlobalIndex(backwardIndex)
                self.setFooterQuoteAfterQuoteChange()
                self.isIntroAnimating = false
            }
        }
    }

    // Animate towards a target verse (same feel as app startup animation)
    func animateTowardsVerse(globalIndex target: Int, pagesAhead: Int = 5) {
        guard !dataSource.isEmpty, !isIntroAnimating else { return }
        // Find target's position within dataSource; fall back to nearest by distance
        let targetPos: Int = dataSource.firstIndex(of: target)
            ?? dataSource.enumerated().min(by: { abs($0.element - target) < abs($1.element - target) })?.offset
            ?? 0
        let aheadPos = min(targetPos + max(1, pagesAhead), dataSource.count - 1)
        let aheadIndex = dataSource[aheadPos]
        guard aheadIndex != target else {
            // Already at the end, just set to target without animation
            selectedGlobalIndex = target
            viewModel.setCurrentByGlobalIndex(target)
            setFooterQuoteAfterQuoteChange()
            return
        }
        isIntroAnimating = true
        let duration: Double = 0.8
        let extraOpacityDuration = 0.1
        // Phase 1: jump ahead without animation
        DispatchQueue.main.async {
            var txn = Transaction()
            txn.disablesAnimations = true
            withTransaction(txn) {
                scrollPosition = aheadIndex
            }
            // Phase 2: animate back to the target verse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(duration: duration, bounce: 0.15)) {
                    scrollPosition = target
                }
                withAnimation(.easeInOut(duration: duration + extraOpacityDuration)) {
                    introOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration + extraOpacityDuration) {
                    selectedGlobalIndex = target
                    viewModel.setCurrentByGlobalIndex(target)
                    setFooterQuoteAfterQuoteChange()
                    isIntroAnimating = false
                }
            }
        }
    }

    private func runGuidanceSearch() {
        guidanceError = nil
        guidanceResults = []
        // Close the sheet immediately on search tap
        showGuidanceSheet = false
        let text = guidanceQuery
        runGuidanceSearch(text: text)
    }

    // Overload that executes the guidance flow for an arbitrary text (used by Emotion Wheel)
    private func runGuidanceSearch(text: String) {
        guidanceError = nil
        guidanceResults = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            guidanceError = "Please enter some text."
            return
        }
        if searchHelper == nil { searchHelper = LessonSearchHelper() }
        guard let helper = searchHelper else {
            guidanceError = "Failed to initialize search."
            return
        }
        isSearchingGuidance = true
        // Immediately animate away from current verse (backwards)
        animateAwayFromCurrentBackwards()
        let k = guidanceTopK
        let rk = max(k, guidanceRetrieveTopK)
        DispatchQueue.global(qos: .userInitiated).async {
            let results = helper.search(text: trimmed, topK: k, retrieveTopK: rk, doRerank: true)
            DispatchQueue.main.async {
                self.guidanceResults = results
                self.isSearchingGuidance = false
                // Weighted pick from top K (default 0.5/0.3/0.2)
                if !results.isEmpty {
                    let chosenOffset = LessonNavigationHelper.pickWeightedTopIndex(count: results.count)
                    let chosen = results[chosenOffset]
                    let rowIndex = Int(chosen.id)
                    if self.unitsIndex == nil { self.unitsIndex = LessonUnitsIndex() }
                    if let uidx = self.unitsIndex {
                        let units = uidx.units(forEmbeddingIndex: rowIndex)
                        let cid = uidx.oldClusterId(forEmbeddingIndex: rowIndex) ?? -1
                        let compact = units.map { "\($0.chapter).\($0.start)–\($0.end)" }.joined(separator: ", ")
                        print("Chosen mapping (offset=\(chosenOffset)) → row=\(rowIndex) old_cluster_id=\(cid) units=[\(compact)]")
                        // Navigate: pick a random UnitRange and animate towards it after away animation completes
                        if let target = LessonNavigationHelper.pickRandomTarget(from: units) {
                            let globalIdx = LessonNavigationHelper.globalIndex(forChapter: target.chapter, verse: target.verse)
                            DispatchQueue.main.asyncAfter(deadline: .now() + LessonNavigationHelper.awayDuration) {
                                self.animateTowardsVerse(globalIndex: globalIdx)
                            }
                        }
                    } else {
                        print("LessonUnitsIndex unavailable; cannot map units for top result")
                    }
                }
            }
        }
    }
}

// MARK: - Emotion Wheel Container
extension VerseView {
    struct EmotionWheelContainerView: View {
        @Environment(\.colorScheme) private var colorScheme
        let isBookmarked: Bool
        let onQuery: ((String) -> Void)?
        @State private var nodes: [EmotionNode] = []
        var body: some View {
            ZStack {
                (colorScheme == .light ? AppColors.parchment.linearGradient : (isBookmarked ? AppColors.lavender.linearGradient : AppColors.peacockBackground))
                    .ignoresSafeArea()
                Group {
                    if nodes.isEmpty {
                        ProgressView()
                            .task {
                                if let loaded = try? EmotionWheelLoader.load() { nodes = loaded }
                            }
                    } else {
                        EmotionWheelView(roots: nodes) { query in
                            onQuery?(query)
                        }
                    }
                }
            }
        }
    }
}





