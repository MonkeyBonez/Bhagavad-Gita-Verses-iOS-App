//
//  HomeScreenWidgetOnboarding.swift
//  Bhagavad Gita Verses
//
//  Created by Snehal Mulchandani on 9/4/25.
//

import SwiftUI

struct HomeScreenWidgetOnboarding: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var step: Int = 0

    private var foreground: Color {
        colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment
    }

    private var background: some View {
        colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.peacockBackground
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Heading (single line/paragraph per step; system font per request)
                    VStack(spacing: 16) {
                        Text(titleForStep(step))
                            .font(.system(size: 22, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }
                    .foregroundStyle(foreground)
                    .padding(.top, 16)

                    Spacer(minLength: 8)

                    // Sketch area - sized by width naturally via aspect ratio; no hard-coded height
                    Group {
                        switch step {
                        case 0:
                            PhoneHomeScreenSketchView(showEditMode: false, showMediumWidget: false, showAppsGrid: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        case 1:
                            PhoneHomeScreenSketchView(showEditMode: true, showMediumWidget: false, showAppsGrid: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        default:
                            PhoneHomeScreenSketchView(showEditMode: false, showMediumWidget: true, showAppsGrid: false)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 8)

                    // Footer CTA
                    Group {
                        if step < 2 {
                            Button("Next") { withAnimation { step += 1 } }
                                .buttonStyle(PrimaryButtonStyle(accent: foreground, foreground: colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock, fullWidth: true))
                        } else {
                            Button("Got it") { dismiss() }
                                .buttonStyle(PrimaryButtonStyle(accent: foreground, foreground: colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock, fullWidth: true))
                        }
                    }
                    .padding(20)

                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { idx in
                            Circle()
                                .fill(idx == step ? foreground : foreground.opacity(0.35))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        if step == 0 { dismiss() } else { withAnimation { step -= 1 } }
                    }) {
                        Image(systemName: step == 0 ? "xmark" : "chevron.left")
                    }
                    .tint(foreground)
                }
            }
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private func titleForStep(_ s: Int) -> String {
        switch s {
        case 0: return "Press and hold anywhere on your\nhome screen"
        case 1:
            if #available(iOS 26.0, *) {
                return "Tap the “Edit” button in the top left corner and add widget"
            } else {
                return "Tap the “+” button in the\ntop left corner"
            }
        default: return "Search Sattva and pick the\nverse or lesson widget"
        }
    }
}

#Preview {
    HomeScreenWidgetOnboarding()
}

