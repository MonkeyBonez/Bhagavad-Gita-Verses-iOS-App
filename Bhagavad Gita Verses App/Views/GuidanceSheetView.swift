import SwiftUI

struct GuidanceSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEditorFocused: Bool

    @Binding var query: String
    @Binding var topK: Int
    @Binding var retrieveTopK: Int

    let isSearching: Bool
    let errorText: String?
    let results: [LessonResult]

    let onSearch: () -> Void
    let onClose: () -> Void

    let isBookmarked: Bool

    private var background: some View {
        colorScheme == .light
        ? (isBookmarked ? AppColors.lavender.linearGradient : AppColors.parchment.linearGradient)
        : AppColors.peacockBackground
    }

    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : (isBookmarked ? AppColors.lavender : AppColors.parchment)
    }
    
    private var fontSize: CGFloat {
        16
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $query)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: fontSize))
                        .foregroundStyle(foregroundColor)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .background(Color.clear)
                        .focused($isEditorFocused)
                    if query.isEmpty {
                        Text("What do you need help navigating?")
                            .font(.system(size: fontSize))
                            .foregroundStyle(foregroundColor.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding()
            .task {
                // Focus the editor when the sheet appears
                isEditorFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark")
                    }
                    .tint(foregroundColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(action: { onSearch(); onClose() }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColors.vividPurple)
                        .disabled(isSearching)
                    } else {
                        Button(action: { onSearch(); onClose() }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .tint(foregroundColor)
                        .disabled(isSearching)
                    }
                }
            }
        }
        .background(background.ignoresSafeArea())
    }
}

// MARK: - Preview
#Preview("Guidance Sheet") {
    struct Wrapper: View {
        @State var query: String = ""
        @State var topK: Int = 3
        @State var retrieveTopK: Int = 10
        @State var isBookmarked: Bool = false

        var sample: [LessonResult] {
            [
                LessonResult(id: 0, text: "Act without attachment to results.", cosine: 0.71, ce: 2.13),
                LessonResult(id: 1, text: "Focus on duty, not the fruit.", cosine: 0.69, ce: 1.88),
                LessonResult(id: 2, text: "Offer actions with steadiness.", cosine: 0.66, ce: 1.52)
            ]
        }

        var body: some View {
            GuidanceSheetView(
                query: $query,
                topK: $topK,
                retrieveTopK: $retrieveTopK,
                isSearching: false,
                errorText: nil,
                results: sample,
                onSearch: {},
                onClose: {},
                isBookmarked: isBookmarked
            )
        }
    }
    return Wrapper()
}



