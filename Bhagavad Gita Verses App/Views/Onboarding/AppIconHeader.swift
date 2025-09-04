import SwiftUI

struct AppIconHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
//        VStack(spacing: 12) {
            Image("IconNoBackground")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.25), radius: 8, y: 4)
//            Text("Sattva")
//                .font(.custom(Fonts.verseFontName, size: 24))
//                .bold()
//        }
    }
}

#Preview {
    ZStack {
        AppColors.peacockBackground.ignoresSafeArea()
        AppIconHeader()
            .padding()
    }
}


