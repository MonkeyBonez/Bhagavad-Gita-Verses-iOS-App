import SwiftUI

struct PhoneHomeScreenSketchView: View {
    @Environment(\.colorScheme) private var colorScheme
    var strokeColor: Color {
        (colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment).opacity(0.7)
    }
    var accentColor: Color {
        colorScheme == .light ? AppColors.vividPurple : AppColors.lavender
    }
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 44
    var widgetText: String = "Act with steadiness, free from attachment to results."
    // Onboarding customization
    var showEditMode: Bool = false            // shows minus badges and the system "+" affordance
    var showMediumWidget: Bool = true         // render the medium widget at the top
    var showAppsGrid: Bool = true             // render app grid icons

    // Fixed grid: 6 rows x 4 columns
    private let rows = 6
    private let columns = 4

    // Layout factors (more screen usage)
    private let interIconSpacingFactor: CGFloat = 0.020   // tighter spacing
    private let sideInsetFactor: CGFloat = 0.06           // less side inset
    private let topGridStartFactor: CGFloat = 0.11        // start closer to Island
    private let bottomDockHeightFactor: CGFloat = 0.115

    var body: some View {
        GeometryReader { geo in
            let effectiveStroke = strokeColor
            let effectiveAccent = accentColor
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            // Horizontal sizing
            let sideInset = min(w * sideInsetFactor, w * 0.2)
            let inter = max(w * interIconSpacingFactor, 1)
            let gridWidth = max(w - sideInset * 2, 1)
            let totalInter = inter * CGFloat(columns - 1)
            let iconSizeWidth = max((gridWidth - totalInter) / CGFloat(columns), 1)

            // Dock (kept higher; do not move it down)
            let dockHeight = max(h * bottomDockHeightFactor, 16)
            let dockWidth  = w * 0.86
            let dockY      = h - dockHeight * 0.80

            // Vertical anchors
            let gridTopY   = h * topGridStartFactor

            // Search pill between grid and dock
            let searchHeight: CGFloat = h * 0.04
            let searchWidth: CGFloat  = w * 0.23
            let searchY      = dockY - dockHeight * 0.95  // clearly above dock

            // Fit icon size vertically so 6 rows end above the search pill
            let verticalAvail = max((searchY - searchHeight/2) - gridTopY, 1)
            let iconSizeHeight = max((verticalAvail - inter * CGFloat(rows - 1)) / CGFloat(rows), 1)
            let iconSize = min(iconSizeWidth, iconSizeHeight)
            let iconCorner = iconSize * 0.22
            let rowStep = iconSize + inter

            // .systemMedium widget (2 rows x 4 columns) at the top of the grid
            let mediumWidgetWidth  = iconSize * 4 + inter * 3
            let mediumWidgetHeight = iconSize * 2 + inter

            ZStack {
                // ===== Phone outline =====
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(effectiveStroke, lineWidth: lineWidth)

                // ===== Dynamic Island (UNCHANGED per your request) =====
                Capsule(style: .continuous)
                    .stroke(effectiveStroke, lineWidth: lineWidth)
                    .frame(width: w * 0.3, height: h * 0.035)
                    .position(x: w * 0.50, y: h * 0.045)

                // ===== .systemMedium widget (top; spans 2 rows x all 4 columns) =====
                if showMediumWidget {
                    HomeScreenWidgetTextView(text: widgetText,
                                              width: mediumWidgetWidth,
                                              height: mediumWidgetHeight,
                                              cornerRadius: iconCorner,
                                              strokeColor: effectiveStroke,
                                              accentColor: effectiveAccent,
                                              lineWidth: lineWidth)
                        .position(x: sideInset + gridWidth / 2,
                                  y: gridTopY + mediumWidgetHeight / 2)
                }
                    

                // ===== App icons: exactly 6 rows × 4 columns =====
                if showAppsGrid {
                    // If widget hidden, start from row 0; else skip top 2 rows used by the widget
                    let startRow = showMediumWidget ? 2 : 0
                    ForEach(startRow..<rows, id: \.self) { r in
                        ForEach(0..<columns, id: \.self) { c in
                            let x = sideInset + iconSize/2 + CGFloat(c) * (iconSize + inter)
                            let y = gridTopY + iconSize/2 + CGFloat(r) * rowStep
                            ZStack {
                                RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
                                    .stroke(effectiveStroke, lineWidth: lineWidth)
                                    .frame(width: iconSize, height: iconSize)
                                if showEditMode {
                                    // Larger minus badge, themed (no red)
                                    let badgeR = max(iconSize * 0.30, 10)
                                    let minusThickness = max(badgeR * 0.18, 2)
                                    let minusWidth = badgeR * 0.62
                                    ZStack {
                                        Circle()
                                            .fill(effectiveStroke)
                                            .frame(width: badgeR, height: badgeR)
                                        Rectangle()
                                            .fill(colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock)
                                            .frame(width: minusWidth, height: minusThickness)
                                    }
                                    .frame(width: iconSize, height: iconSize, alignment: .topLeading)
                                    .offset(x: -badgeR * 0.25, y: -badgeR * 0.25)
                                }
                            }
                            .position(x: x, y: y)
                        }
                    }
                }

                // ===== Search pill (between grid and dock) =====
                Capsule(style: .continuous)
                    .stroke(effectiveStroke, lineWidth: lineWidth)
                    .frame(width: searchWidth, height: searchHeight)
                    .position(x: w * 0.5, y: searchY)

                // ===== Dock (outline only; no icons inside) =====
                RoundedRectangle(cornerRadius: h * 0.03, style: .continuous)
                    .stroke(effectiveStroke, lineWidth: lineWidth)
                    .frame(width: dockWidth, height: dockHeight)
                    .position(x: w * 0.5, y: dockY)

                // ===== System "+" affordance (shown in edit mode) =====
                if showEditMode {
                    // iOS-style edit/add affordance (iOS 26 shows Edit)
                    let pillW: CGFloat = w * 0.17
                    let pillH: CGFloat = h * 0.035
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(effectiveStroke)
                        Group {
                            if #available(iOS 26.0, *) {
                                Text("Edit")
                                    .font(.system(size: max(10, pillH * 0.55), weight: .semibold))
                                    .foregroundStyle(colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock)
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: pillH * 0.6, weight: .bold))
                                    .foregroundStyle(colorScheme == .light ? AppColors.parchment : AppColors.greenPeacock)
                            }
                        }
                    }
                    .frame(width: pillW, height: pillH)
                    .position(x: w * 0.15, y: h * 0.045)
                }
            }
        }
        .aspectRatio(9/19.5, contentMode: .fit)
        .padding()
    }
}

// Reusable Home Screen widget mockup with configurable styling
struct HomeScreenWidgetTextView: View {
    var text: String
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
    var strokeColor: Color
    var accentColor: Color
    var lineWidth: CGFloat = 2
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(strokeColor, lineWidth: lineWidth)
            .frame(width: width, height: height)
            .overlay {
                Text(text)
                    .foregroundStyle(accentColor)
                    .font(.custom(Fonts.verseFontName, size: height * 0.50 * 0.28))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal)
                    .shadow(color: strokeColor.opacity(colorScheme == .light ? 0.9 : 0.4), radius: 13, x: 0, y: 3)
            }
    }
}

struct HomeScreenWidgetMockUp: View {
    @Environment(\.colorScheme) private var colorScheme
    var text: String = "Act with steadiness, free from attachment to results."
    var width: CGFloat = 300
    var height: CGFloat = 130
    var cornerRadius: CGFloat = 24
    var lineWidth: CGFloat = 2

    private var stroke: Color {
        (colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment).opacity(0.8)
    }
    private var accent: Color {
        colorScheme == .light ? AppColors.vividPurple : AppColors.lavender
    }

    var body: some View {
        HomeScreenWidgetTextView(
            text: text,
            width: width,
            height: height,
            cornerRadius: cornerRadius,
            strokeColor: stroke,
            accentColor: accent,
            lineWidth: lineWidth,
        )
    }
}

#Preview {
    PhoneHomeScreenSketchView(showEditMode: true)
        .frame(width: 300, height: 650)
}
