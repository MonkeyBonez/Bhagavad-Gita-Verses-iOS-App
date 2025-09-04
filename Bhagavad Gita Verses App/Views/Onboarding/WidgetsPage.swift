import SwiftUI

struct WidgetsPage: View {
    @Binding var showWidgetSheet: Bool
    @Binding var showLockSheet: Bool
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Wisdom at a glance")
                    .font(.custom(Fonts.verseFontName, size: 32))
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Keep the week’s lesson visible on your lock or home screen — gentle reminders to stay aligned throughout your day.")
                    .font(.custom(Fonts.supportingFontName, size: 18))
                    .opacity(0.80)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 2)
                GeometryReader { geo in
                    let phoneWidth = geo.size.width // allow wider when space permits
                    TabView {
                        Button { showLockSheet = true } label: {
                            PhoneScreenWithDateTimeAndWidgetTextView()
                                .frame(width: phoneWidth, alignment: .top)
                                .contentShape(Rectangle())
                        }
                        .tag(0)
                        Button { showWidgetSheet = true } label: {
                            PhoneHomeScreenSketchView()
                                .frame(width: phoneWidth, alignment: .top)
//                                .frame(maxHeight: 600)
                                .contentShape(Rectangle())
                        }
                        .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(maxWidth: .infinity)
//                    .frame(height: 480) // clamp for intentional bottom cut-off
//                    .clipped()
                }
                .frame(height: 700)
            }
//            .padding(.horizontal, 24)
        }
        .scrollDisabled(true)
    }
}

#Preview {
    ZStack {
        AppColors.peacockBackground.ignoresSafeArea()
        WidgetsPage(showWidgetSheet: .constant(false), showLockSheet: .constant(false))
    }
}


