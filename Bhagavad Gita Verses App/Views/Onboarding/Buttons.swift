import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var accent: Color = AppColors.vividPurple
    var foreground: Color = AppColors.parchment
    var fullWidth: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(accent)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var foreground: Color = AppColors.parchment
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(foreground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(foreground.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Primary") {}
            .buttonStyle(PrimaryButtonStyle())
        Button("Secondary") {}
            .buttonStyle(SecondaryButtonStyle(foreground: AppColors.parchment))
    }
    .padding()
    .background(AppColors.peacockBackground)
}


