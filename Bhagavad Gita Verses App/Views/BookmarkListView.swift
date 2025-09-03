import SwiftUI

struct BookmarkListView: View {
    @Environment(\.colorScheme) private var colorScheme
    // Matches VerseView's theme in light mode (lavender when true, parchment when false). Dark uses peacock.
    let isBookmarkedTheme: Bool
    let indices: [Int]
    let verseProvider: (Int) -> Verse
    let onSelect: (Int) -> Void
    let onClose: () -> Void
    @State private var collapseP: CGFloat = 0.0
    @State private var headerHeight: CGFloat = 84
    @Namespace private var titleNamespace

    var body: some View {
        ZStack {
            Group {
                if colorScheme == .light {
                    (isBookmarkedTheme ? AppColors.lavender.linearGradient : AppColors.parchment.linearGradient)
                } else {
                    AppColors.peacockBackground
                }
            }
            .ignoresSafeArea()
            VStack(spacing: 0) {
                // Non-scrollable header area
                ZStack {
                    // Large, leading-aligned title (fades out)
                    HStack {
                        Text("Bookmarks")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                            .allowsTightening(false)
                            .minimumScaleFactor(0.95)
                            .padding(.leading, 20)
                        Spacer(minLength: 0)
                    }
                    .opacity(max(0, 1 - collapseP))

                    // Small, centered title (fades in)
                    HStack {
                        Spacer(minLength: 0)
                        Text("Bookmarks")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                            .allowsTightening(false)
                            .minimumScaleFactor(0.95)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: 15)
                    }
                    .opacity(min(1, collapseP))
                }
                .padding(.top, 24)
                .padding(.bottom, 8)
                .animation(.easeOut(duration: 0.2), value: collapseP)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { headerHeight = geo.size.height }
                            .onChange(of: geo.size.height) { oldValue, newValue in
                                headerHeight = newValue
                            }
                    }
                )
                .allowsHitTesting(false)

                // Scrollable content area
                ScrollView {
                    VStack(spacing: 12) {
                        // Marker to track scroll offset relative to the ScrollView
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: FirstCardMinYKey.self, value: geo.frame(in: .named("bookmarksScroll")).minY)
                        }
                        .frame(height: 1)
                        ForEach(indices, id: \.self) { idx in
                            let verse = verseProvider(idx)
                            Button {
                                onSelect(idx)
                            } label: {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Badge
                                    HStack {
                                        CapsuleBadge(
                                            text: "\(verse.chapterNumber).\(verse.verseNumber)",
                                            textColor: primaryTextColor,
                                            backgroundColor: badgeBackgroundColor
                                        )
                                        Spacer(minLength: 0)
                                    }
                                    // Verse text
                                    Text(verse.text)
                                        .font(.custom(Fonts.verseFontName, size: 20))
                                        .foregroundStyle(primaryTextColor)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(cardBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .stroke(colorScheme == .light ? .black.opacity(0.06) : .white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(CardButtonStyle())
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "bookmarksScroll")
            }
            .onPreferenceChange(FirstCardMinYKey.self) { y in
                let offset = max(0, -y)
                let p = headerHeight > 0 ? min(1, offset / headerHeight) : 0
                collapseP = p
            }
            .animation(.easeInOut(duration: 0.2), value: collapseP)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onClose() }
                        .foregroundStyle(primaryTextColor)
                }
            }
        }
        .coordinateSpace(name: "container")
    }
        
        // MARK: Badge
        private struct CapsuleBadge: View {
            let text: String
            let textColor: Color
            let backgroundColor: Color
            var body: some View {
                Text(text)
                    .font(.custom(Fonts.supportingFontName,size: 15))
                    .fontWeight(.semibold)
                    .foregroundStyle(textColor)
                    .opacity(0.85)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(backgroundColor)
                    )
            }
        }
        
        // MARK: Press effect like iOS cards
        private struct CardButtonStyle: ButtonStyle {
            func makeBody(configuration: Configuration) -> some View {
                configuration.label
                    .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0.001))
                    )
                    .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            }
        }
    }

#Preview("Bookmark List — Sample") {
    let sampleVerses: [Int: Verse] = [
        0: Verse(text: "You have a right to perform your prescribed duty, but you are not entitled to the fruits of action.", chapterNumber: 2, verseNumber: 47, bookmarked: true),
        1: Verse(text: "Abandon all varieties of religion and just surrender unto Me. I shall deliver you from all sinful reactions. Do not fear.", chapterNumber: 18, verseNumber: 66, bookmarked: true),
        2: Verse(text: "Whenever and wherever there is a decline in religious practice, O descendant of Bharata, and a predominant rise of irreligion—at that time I descend Myself.", chapterNumber: 4, verseNumber: 7, bookmarked: true),
        3: Verse(text: "After many births and deaths, he who is actually in knowledge surrenders unto Me, knowing Me to be the cause of all causes and all that is.", chapterNumber: 7, verseNumber: 19, bookmarked: true)
    ]
    return BookmarkListView(
        isBookmarkedTheme: true,
        indices: [0, 1, 2, 3],
        verseProvider: { sampleVerses[$0] ?? Verse(text: "", chapterNumber: 1, verseNumber: 1) },
        onSelect: { _ in },
        onClose: {}
    )
}

private extension BookmarkListView {
    var primaryTextColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : (isBookmarkedTheme ? AppColors.lavender : AppColors.parchment)
    }
    var secondaryTextColor: Color {
        primaryTextColor.opacity(0.7)
    }
    var badgeBackgroundColor: Color {
        if colorScheme == .light {
            return primaryTextColor.opacity(0.12)
        }
        return Color.white.opacity(0.12)
    }
    var cardBackgroundColor: Color {
        if colorScheme == .light {
            if isBookmarkedTheme {
                // Slightly darker than lavender for contrast
                return Color(red: 219/255.0, green: 210/255.0, blue: 245/255.0)
            } else {
                // Requested parchment card color
                return Color(red: 0xE8/255.0, green: 0xDF/255.0, blue: 0xC6/255.0)
            }
        }
        // Dark mode: subtle glass
        return Color.white.opacity(0.06)
    }
}

// PreferenceKey to track scroll offset in named coordinate space
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Tracks the minY of the first card in the ScrollView's coordinate space
private struct FirstCardMinYKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


