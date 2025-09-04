import SwiftUI

struct PhoneScreenWithDateTimeAndWidgetTextView: View {
    var strokeColor: Color = AppColors.parchment
    var accentColor: Color = AppColors.lavender
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 44

    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // 12-hour clock, no AM/PM
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    // iOS lock screen style short date, e.g. "Wed, Sep 3"
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    // Widget text
    var widgetText: String = "Act with steadiness, free from attachment to results."

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Screen outline
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)

                // ==== Dynamic Island (top pill) ====
                Capsule(style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: w * 0.3, height: h * 0.035)   // ~iPhone proportion
                    .position(x: w * 0.50, y: h * 0.045)        // sits near the very top

                // Date (small, above time)
                Text(Self.dateFormatter.string(from: currentDate))
                    .font(.system(size: h * 0.03, weight: .semibold))
                    .foregroundColor(strokeColor)
                    .position(x: w * 0.50, y: h * 0.12)

                // Time (large, thin)
                Text(Self.timeFormatter.string(from: currentDate))
                    .font(.system(size: h * 0.14, weight: .thin))
                    .foregroundColor(strokeColor)
                    .position(x: w * 0.50, y: h * 0.20)

                // Widget text (below time)
                Text(widgetText)
                    .foregroundStyle(accentColor)
                    .font(.system(size: h * 0.023, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(width: w * 0.80)
                    .position(x: w * 0.50, y: h * 0.30)

                // ==== Bottom controls ====
                // Camera (right circle)
                Circle()
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: h * 0.072, height: h * 0.072)  // button diameter
                    .position(x: w * 0.82, y: h * 0.9)

                // Flashlight (left circle)
                Circle()
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: h * 0.072, height: h * 0.072)
                    .position(x: w * 0.18, y: h * 0.9)

                // Home indicator (swipe bar)
                Capsule(style: .continuous)
                    .fill(strokeColor.opacity(0.9))              // filled like iOS
                    .frame(width: w * 0.32, height: h * 0.008)
                    .position(x: w * 0.50, y: h * 0.985)
            }
        }
        .aspectRatio(9/19.5, contentMode: .fit)
        .padding()
        .onReceive(timer) { currentDate = $0 }
    }
}

#Preview {
    PhoneScreenWithDateTimeAndWidgetTextView()
        .frame(width: 300)
        .background(AppColors.greenPeacock)
}
