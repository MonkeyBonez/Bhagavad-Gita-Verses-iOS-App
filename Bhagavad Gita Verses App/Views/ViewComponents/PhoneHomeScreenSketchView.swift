import SwiftUI

struct PhoneHomeScreenSketchView: View {
    var strokeColor: Color = .primary
    var accentColor: Color = AppColors.lavender
    var lineWidth: CGFloat = 2
    var cornerRadius: CGFloat = 44
    var widgetText: String = "Act with steadiness, free from attachment to results."

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
            let dockY      = h - dockHeight * 0.66

            // Vertical anchors
            let gridTopY   = h * topGridStartFactor

            // Search pill between grid and dock
            let searchHeight: CGFloat = h * 0.04
            let searchWidth: CGFloat  = w * 0.50
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
                    .stroke(strokeColor, lineWidth: lineWidth)

                // ===== Dynamic Island (UNCHANGED per your request) =====
                Capsule(style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: w * 0.3, height: h * 0.035)
                    .position(x: w * 0.50, y: h * 0.045)

                // ===== .systemMedium widget (top; spans 2 rows x all 4 columns) =====
                RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: mediumWidgetWidth, height: mediumWidgetHeight)
                    .position(
                        x: sideInset + gridWidth / 2,
                        y: gridTopY + mediumWidgetHeight / 2
                    )
                    .overlay {
                        Text(widgetText)
                            .foregroundStyle(accentColor)
                            .frame(width: mediumWidgetWidth, height: mediumWidgetHeight)
                            .font(.system(size: h * 0.023, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                            .position(
                                x: sideInset + gridWidth / 2,
                                y: gridTopY + mediumWidgetHeight / 2
                            )
                    }

                // ===== App icons: exactly 6 rows × 4 columns =====
                // Skip rows 0 and 1 (they’re occupied by the medium widget)
                ForEach(2..<rows, id: \.self) { r in
                    ForEach(0..<columns, id: \.self) { c in
                        let x = sideInset + iconSize/2 + CGFloat(c) * (iconSize + inter)
                        let y = gridTopY + iconSize/2 + CGFloat(r) * rowStep
                        RoundedRectangle(cornerRadius: iconCorner, style: .continuous)
                            .stroke(strokeColor, lineWidth: lineWidth)
                            .frame(width: iconSize, height: iconSize)
                            .position(x: x, y: y)
                    }
                }

                // ===== Search pill (between grid and dock) =====
                Capsule(style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: searchWidth, height: searchHeight)
                    .position(x: w * 0.5, y: searchY)

                // ===== Dock (outline only; no icons inside) =====
                RoundedRectangle(cornerRadius: h * 0.03, style: .continuous)
                    .stroke(strokeColor, lineWidth: lineWidth)
                    .frame(width: dockWidth, height: dockHeight)
                    .position(x: w * 0.5, y: dockY)
            }
        }
        .aspectRatio(9/19.5, contentMode: .fit)
        .padding()
    }
}

#Preview {
    PhoneHomeScreenSketchView()
        .frame(width: 300, height: 650)
}
