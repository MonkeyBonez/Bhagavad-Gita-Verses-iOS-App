import SwiftUI

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Live aligned with the Gita")
                .font(.custom(Fonts.verseFontName, size: 32))
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
//                .padding(.bottom, 4)
            Text("Weekly lessons and personalized guidance")
                .font(.custom(Fonts.supportingFontName, size: 18))
                .opacity(0.80)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.bottom, 2)
            VStack(spacing: 8) {
                Text("Sattva (n.)")
                    .font(.custom(Fonts.verseFontName, size: 26))
                    .fontWeight(.bold)
                Text("The quality of truth, purity, and goodness; \nthe principle of harmony and clarity in \nIndian philosophy.")
                    .font(.custom(Fonts.supportingFontName, size: 17))
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineSpacing(7)
                    .opacity(0.8)
//                    .padding(.horizontal, 30)
            }
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        AppColors.parchmentSolidAsGradient.ignoresSafeArea()
        WelcomePage()
            .foregroundStyle(AppColors.greenPeacock)
    }
}


