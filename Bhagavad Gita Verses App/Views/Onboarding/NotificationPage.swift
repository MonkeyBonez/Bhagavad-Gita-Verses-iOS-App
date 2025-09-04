import SwiftUI

struct NotificationPage: View {
    let onEnable: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Text("New lessons every week")
                .font(.custom(Fonts.verseFontName, size: 32))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("We’ll remind you to review each week’s lesson — at the right time. You can change this anytime in Settings.")
                .font(.custom(Fonts.supportingFontName, size: 18))
                .opacity(0.80)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        AppColors.parchment.ignoresSafeArea()
        NotificationPage(onEnable: {})
    }
}


