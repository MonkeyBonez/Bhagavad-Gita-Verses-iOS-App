import SwiftUI

struct EmotionWheelContainerView: View {
    @Environment(\.colorScheme) private var colorScheme
    let isBookmarked: Bool
    let onQuery: ((String) -> Void)?
    @State private var nodes: [EmotionNode] = []
    var body: some View {
        ZStack {
            (colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.peacockBackground)
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


