import SwiftUI

struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var selection = 0
    @State private var showWidgetSheet = false
    @State private var showLockSheet = false
    @State private var isRequestingNotifications = false
    @State private var spinToken: Int = 0

    var background: some View {
        colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.peacockBackground
    }
    
    var backgroundColor: Color {
        colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock
    }

    var foreground: Color {
        colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment
    }

    
    var accent: Color {
        colorScheme == .light ? AppColors.vividPurple : AppColors.lavender
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 0) {
                AppIconHeader()
                    .padding(.top, 24)
                    .padding(.bottom, -10)

                // Page-specific content near the top
                Group {
                    switch selection {
                    case 0:
                        WelcomePage()
                    case 1:
                        NotificationPage(onEnable: requestNotifications)
                    default:
                        WidgetsPage(showWidgetSheet: $showWidgetSheet, showLockSheet: $showLockSheet)
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                // Mandala sits just above the footer for steps 0 and 1
                if selection <= 1 {
                    OnboardingMandalaView(spinToken: spinToken)
                        .frame(width: 50, height: 50)
                        .padding(.bottom, 120)
                }

                // Footer button
                buttonView
                    .padding(20)

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<3) { idx in
                        Circle()
                            .fill(idx == selection ? foreground : foreground.opacity(0.35))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .foregroundStyle(foreground)
        .sheet(isPresented: $showWidgetSheet) { ThemedBlankSheet() }
        .sheet(isPresented: $showLockSheet) { ThemedBlankSheet() }
    }
    
    var buttonView: some View {
        Group {
            if selection == 0 {
                Button("Begin") {
                    withAnimation { selection += 1 }
                    spinToken += 1
                }
                    .buttonStyle(PrimaryButtonStyle(accent: foreground, foreground: backgroundColor, fullWidth: true))
            } else if selection == 1 {
                Button("Enable notifications") {
                    withAnimation { requestNotifications() }
                    spinToken += 1
                }
                    .buttonStyle(PrimaryButtonStyle(accent: foreground, foreground: backgroundColor, fullWidth: true))
            } else {
                Button("Done") {
                    SharedDefaults.defaults.set(true, forKey: "onboarding_completed_v1")
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(accent: accent, foreground: backgroundColor, fullWidth: true))
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func requestNotifications() {
        guard !isRequestingNotifications else { return }
        isRequestingNotifications = true
        WeeklyNotificationScheduler.userTappedEnableNotifications { _ in
            isRequestingNotifications = false
            withAnimation { selection = 2 }
        }
    }
}

#Preview {
    OnboardingView()
}


