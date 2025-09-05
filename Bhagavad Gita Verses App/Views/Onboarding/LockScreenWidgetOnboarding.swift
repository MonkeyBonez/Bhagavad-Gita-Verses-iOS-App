//
//  LockScreenWidgetOnboarding.swift
//  Bhagavad Gita Verses
//
//  Created by Snehal Mulchandani on 9/4/25.
//

import SwiftUI

struct LockScreenWidgetOnboarding: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var step: Int = 0
    @State private var pulseToPurple: Bool = false
    @State private var pulseTimer: Timer? = nil

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
                    // Heading
                    Text(titleForLockScreenStep(step))
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(foreground)
                        .padding(.horizontal, 30)
                        .padding(.top, 16)

                    Spacer(minLength: 8)

                    // Sketch area
                    Group {
                        switch step {
                        case 0:
                            PhoneScreenWithDateTimeAndWidgetTextView(showWidgetText: false)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        case 1:
                            PhoneScreenWithDateTimeAndWidgetTextView(
                                showWidgetText: false,
                                showCustomizePill: true,
                                useStrokeForWidget: false,
                                contentScale: 0.7,
                                showOutline: true,
                                showDynamicIsland: true,
                                showDateAndTime: true,
                                showBottomControls: false,
                                showSmallBottomControls: true,
                                showInnerOutline: true
                            )
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        case 2:
                            PhoneScreenWithDateTimeAndWidgetTextView(showWidgetText: false, showWidgetHighlight: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        case 3:
                            PhoneScreenWithDateTimeAndWidgetTextView(showWidgetText: true, useStrokeForWidget: true, disableWidgetTextShadow: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                        default:
                            PhoneScreenWithDateTimeAndWidgetTextView(showWidgetText: true, useStrokeForWidget: true, overrideAllToVividPurple: pulseToPurple, disableWidgetTextShadow: true)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .onAppear { startColorPulse() }
                                .onDisappear { stopColorPulse() }
                        }
                    }
                    

                    Spacer(minLength: 8)

                    // Footer CTA
                    Group {
                        if step < 4 {
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
                        ForEach(0..<5) { idx in
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

    private func titleForLockScreenStep(_ s: Int) -> String {
        switch s {
        case 0:
            return "Press and hold on your Lock Screen"
        case 1:
            if #available(iOS 26.0, *) {
                return "Tap Customize\n"
            } else {
                return "Tap Customize and choose your Lock Screen"
            }
        case 2:
            return "Tap the widget area below the clock"
        case 3:
            return "Scroll to or search Sattva and add the widget"
        case 4:
            return "To open color options, tap on the time"
        default:
            return ""
        }
    }
}

// MARK: - Color pulse helpers
extension LockScreenWidgetOnboarding {
    private func startColorPulse() {
        stopColorPulse()
        pulseToPurple = false
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: true) { _ in
            withAnimation(.easeOut(duration: 1.3)) {
                pulseToPurple.toggle()
            }
        }
    }
    private func stopColorPulse() {
        pulseTimer?.invalidate(); pulseTimer = nil
        pulseToPurple = false
    }
}

#Preview {
    LockScreenWidgetOnboarding()
}

