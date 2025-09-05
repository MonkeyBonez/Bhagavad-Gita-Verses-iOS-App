import SwiftUI

struct PhoneScreenWithDateTimeAndWidgetTextView: View {
    @Environment(\.colorScheme) private var colorScheme
    var strokeColor: Color {
        (colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment).opacity(0.8)
    }
    var accentColor: Color {
        colorScheme == .light ? AppColors.vividPurple : AppColors.lavender
    }
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
    var widgetText: String = "Act with steadiness, free from\nattachment to results."
    // Onboarding customizations
    var showWidgetText: Bool = true
    var showCustomizePill: Bool = false
    var useStrokeForWidget: Bool = false
    var overrideAllToVividPurple: Bool = false
    var showWidgetHighlight: Bool = false
    var disableWidgetTextShadow: Bool = false
    var contentScale: CGFloat = 1.0
    // Chrome toggles to support composite layouts
    var showOutline: Bool = true
    var showDynamicIsland: Bool = true
    var showDateAndTime: Bool = true
    var showBottomControls: Bool = true
    var showSmallBottomControls: Bool = false
    var showInnerOutline: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Screen outline at 1.0 scale
                if showOutline {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: lineWidth)
                }

                // Dynamic Island at 1.0 scale
                if showDynamicIsland {
                    Capsule(style: .continuous)
                        .stroke(strokeColor, lineWidth: lineWidth)
                        .frame(width: w * 0.3, height: h * 0.035)
                        .position(x: w * 0.50, y: h * 0.045)
                }

                // Scaled inner content: date/time/widget/highlight
                ZStack {
                    if showInnerOutline {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(strokeColor, lineWidth: lineWidth)
                    }
                    // Date
                    if showDateAndTime {
                        Text(Self.dateFormatter.string(from: currentDate))
                            .font(.system(size: h * 0.03, weight: .semibold))
                            .foregroundColor(overrideAllToVividPurple ? AppColors.vividPurple : strokeColor)
                            .position(x: w * 0.50, y: h * 0.12)
                    }
                    // Time
                    if showDateAndTime {
                        Text(Self.timeFormatter.string(from: currentDate))
                            .font(.system(size: h * 0.14, weight: .thin))
                            .foregroundColor(overrideAllToVividPurple ? AppColors.vividPurple : strokeColor)
                            .position(x: w * 0.50, y: h * 0.20)
                    }
                    // Widget text
                    if showWidgetText {
                        let textColor = overrideAllToVividPurple ? AppColors.vividPurple : (useStrokeForWidget ? (colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment) : accentColor)
                        LockScreenWidgetTextView(text: widgetText, textColor: textColor, disableShadow: disableWidgetTextShadow)
                            .frame(width: w, height: h)
                            .position(x: w * 0.50, y: h * 0.30)
                    }
                    if showWidgetHighlight {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(overrideAllToVividPurple ? AppColors.vividPurple : strokeColor, lineWidth: lineWidth)
                            .frame(width: w * 0.80, height: h * 0.06)
                            .position(x: w * 0.50, y: h * 0.30)
                    }
                    if showSmallBottomControls {
                        // Camera (right circle)
                        Circle()
                            .stroke(strokeColor, lineWidth: lineWidth)
                            .frame(width: h * 0.072, height: h * 0.072)
                            .position(x: w * 0.82, y: h * 0.9)
                        // Flashlight (left circle)
                        Circle()
                            .stroke(strokeColor, lineWidth: lineWidth)
                            .frame(width: h * 0.072, height: h * 0.072)
                            .position(x: w * 0.18, y: h * 0.9)
                        // Home indicator (swipe bar)
    //                    Capsule(style: .continuous)
    //                        .fill(strokeColor.opacity(0.9))
    //                        .frame(width: w * 0.32, height: h * 0.008)
    //                        .position(x: w * 0.50, y: h * 0.985)
                    }
                }
                .frame(width: w, height: h)
                .position(x: w * 0.5, y: h * 0.5)
                .scaleEffect(contentScale)

                if showBottomControls {
                    // Camera (right circle)
                    Circle()
                        .stroke(strokeColor, lineWidth: lineWidth)
                        .frame(width: h * 0.072, height: h * 0.072)
                        .position(x: w * 0.82, y: h * 0.9)
                    // Flashlight (left circle)
                    Circle()
                        .stroke(strokeColor, lineWidth: lineWidth)
                        .frame(width: h * 0.072, height: h * 0.072)
                        .position(x: w * 0.18, y: h * 0.9)
                    // Home indicator (swipe bar)
//                    Capsule(style: .continuous)
//                        .fill(strokeColor.opacity(0.9))
//                        .frame(width: w * 0.32, height: h * 0.008)
//                        .position(x: w * 0.50, y: h * 0.985)
                }

                // Customize pill (onboarding step) at 1.0 scale on top
                if showCustomizePill {
                    let pillW: CGFloat = w * 0.44
                    let pillH: CGFloat = h * 0.06
                    Capsule(style: .continuous)
                        .stroke(strokeColor, lineWidth: lineWidth)
                        .frame(width: pillW, height: pillH)
                        .overlay {
                            Text("Customize")
                                .font(.system(size: pillH * 0.40, weight: .semibold))
                                .foregroundStyle(strokeColor)
                        }
                        .position(x: w * 0.50, y: h * 0.90)
                }
            }
        }
        .aspectRatio(9/19.5, contentMode: .fit)
        .padding()
        .onReceive(timer) { currentDate = $0 }
    }
}

struct LockScreenWidgetTextView: View {
    @Environment(\.colorScheme) private var colorScheme
    var text: String = "Act with steadiness, free from\nattachment to results."
    // Appearance defaults match PhoneScreenWithDateTimeAndWidgetTextView
    var widthFraction: CGFloat = 0.80
    var shadowOpacity: Double = 0.9
    var shadowRadius: CGFloat = 13
    var shadowOffsetY: CGFloat = 3
    var textColor: Color? = nil
    var disableShadow: Bool = false

    private var accent: Color {
        colorScheme == .light ? AppColors.vividPurple : AppColors.lavender
    }
    private var stroke: Color {
        (colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Text(text)
                .foregroundStyle(textColor ?? accent)
                .font(.custom(Fonts.verseFontName, size: h * 0.028))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(width: w * widthFraction)
                .shadow(color: (disableShadow ? .clear : stroke.opacity(colorScheme == .light ? shadowOpacity : 0.4)), radius: shadowRadius, x: 0, y: shadowOffsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

#Preview {
    ZStack {
        PhoneScreenWithDateTimeAndWidgetTextView()
            .frame(width: 300)
    }
}
