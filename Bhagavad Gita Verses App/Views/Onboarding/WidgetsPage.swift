import SwiftUI
import UIKit

struct WidgetsPage: View {
    @Binding var showWidgetSheet: Bool
    @Binding var showLockSheet: Bool
    @State private var lockScale: CGFloat = 1.0
    @State private var homeScale: CGFloat = 1.0
    @State private var lockAnimTask: Task<Void, Never>?
    @State private var homeAnimTask: Task<Void, Never>?
    @State private var tabSelection: Int = 0
    @State private var didRunPeek: Bool = false
    @State private var peekTask: Task<Void, Never>?
    @State private var interactionsEnabled: Bool = false

    private func startLockAnimation() {
        lockAnimTask?.cancel()
        lockAnimTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 4.0)) { lockScale = 1.04 }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 8.0)) { lockScale = 1.0 }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func startHomeAnimation() {
        homeAnimTask?.cancel()
        homeAnimTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.easeOut(duration: 4.0)) { homeScale = 1.04 }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 8.0)) { homeScale = 1.0 }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    private func runPeekIfNeeded() {
        guard !didRunPeek else { return }
        didRunPeek = true
        peekTask?.cancel()
        peekTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.6)) { tabSelection = 1 }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.6)) { tabSelection = 0 }
            interactionsEnabled = true
            startHomeAnimation()
            startLockAnimation()
        }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Wisdom at a glance")
                    .font(.custom(Fonts.verseFontName, size: 32))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Keep the week’s lesson visible on your lock or home screen — gentle reminders to stay aligned throughout your day.\nTap screen to learn how.")
                    .font(.custom(Fonts.supportingFontName, size: 18))
                    .opacity(0.80)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 2)
                GeometryReader { geo in
                    let phoneWidth = geo.size.width // allow wider when space permits
                    TabView(selection: $tabSelection) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showLockSheet = true
                        } label: {
                            PhoneScreenWithDateTimeAndWidgetTextView()
                                .frame(width: phoneWidth, alignment: .top)
                                .contentShape(Rectangle())
                                .scaleEffect(lockScale)
//                                .offset(y: lockScale > 1.0 ? -6 : 0)
                        }
                        .tag(0)
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showWidgetSheet = true
                        } label: {
                            PhoneHomeScreenSketchView()
                                .frame(width: phoneWidth, alignment: .top)
//                                .frame(maxHeight: 600)
                                .contentShape(Rectangle())
                                .scaleEffect(homeScale)
//                                .offset(y: homeScale > 1.0 ? -6 : 0)
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(interactionsEnabled)
                    .onAppear {
                        runPeekIfNeeded()
                    }
                    .onChange(of: tabSelection) { _, _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 1.0)
                    }
//                    .frame(height: 480) // clamp for intentional bottom cut-off
//                    .clipped()
                }
                .frame(height: 700)
            }
//            .padding(.horizontal, 24)
        }
        .scrollDisabled(true)
        .onDisappear {
            peekTask?.cancel()
            peekTask = nil
            lockAnimTask?.cancel()
            lockAnimTask = nil
            homeAnimTask?.cancel()
            homeAnimTask = nil
            lockScale = 1.0
            homeScale = 1.0
        }
    }
}

#Preview {
    ZStack {
        AppColors.parchmentSolidAsGradient.ignoresSafeArea()
        WidgetsPage(showWidgetSheet: .constant(false), showLockSheet: .constant(false))
    }
}


