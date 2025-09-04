import SwiftUI

struct ThemedBlankSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        ZStack {
            (colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.peacockBackground)
                .ignoresSafeArea()
            Text("Coming soon")
                .font(.custom(Fonts.supportingFontName, size: 18))
                .foregroundStyle(colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment)
        }
    }
}

#Preview {
    ThemedBlankSheet()
}


