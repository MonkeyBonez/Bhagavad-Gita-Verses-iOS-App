import SwiftUI

struct OnboardingMandalaView: View {
    @Environment(\.colorScheme) private var colorScheme
    var strokeColor: Color {
        colorScheme == .light ? AppColors.greenPeacock : AppColors.parchment
    }
    var baseOpacity: Double = 0.18
    // External trigger to perform a quick ease-out spin (e.g., when paging)
    var spinToken: Int = 0
    @State private var rotation: Angle = .degrees(0)
    @State private var spinAddDegrees: Double = 0

    private func startContinuousSpin() {
        // Reset base rotation and restart perpetual spin
        rotation = .degrees(0)
        withAnimation(.linear(duration: 120).repeatForever(autoreverses: false)) {
            rotation = .degrees(360)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let size = min(w, h)
            let cx = w / 2
            let cy = h / 2
            // Match the React SVG's 200x200 viewBox by scaling radii from that basis
            let s = size / 50.0

            let color = strokeColor.opacity(baseOpacity)

            ZStack {
                // Outer rings (r = 90, 75)
                Circle()
                    .stroke(color, lineWidth: 0.5 * s)
                    .frame(width: 2 * 90 * s, height: 2 * 90 * s)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(color, lineWidth: 0.3 * s)
                    .frame(width: 2 * 75 * s, height: 2 * 75 * s)
                    .position(x: cx, y: cy)

                // Petal pattern: 8 around
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * 45.0 * Double.pi / 180.0
                    let x1 = cx + CGFloat(cos(angle)) * 50 * s
                    let y1 = cy + CGFloat(sin(angle)) * 50 * s
                    let x2 = cx + CGFloat(cos(angle)) * 70 * s
                    let y2 = cy + CGFloat(sin(angle)) * 70 * s

                    // Small ring at x1,y1 (r = 8)
                    Circle()
                        .stroke(color, lineWidth: 0.3 * s)
                        .frame(width: 2 * 8 * s, height: 2 * 8 * s)
                        .position(x: x1, y: y1)

                    // Radial line from center to x2,y2
                    Path { p in
                        p.move(to: CGPoint(x: cx, y: cy))
                        p.addLine(to: CGPoint(x: x2, y: y2))
                    }
                    .stroke(color, lineWidth: 0.2 * s)
                }

                // Inner geometric pattern (r = 30, 15)
                Circle()
                    .stroke(color, lineWidth: 0.4 * s)
                    .frame(width: 2 * 30 * s, height: 2 * 30 * s)
                    .position(x: cx, y: cy)
                Circle()
                    .stroke(color, lineWidth: 0.3 * s)
                    .frame(width: 2 * 15 * s, height: 2 * 15 * s)
                    .position(x: cx, y: cy)

                // Center lotus: 6 small dots around r = 20 (each r = 3)
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) * 60.0 * Double.pi / 180.0
                    let x = cx + CGFloat(cos(angle)) * 20 * s
                    let y = cy + CGFloat(sin(angle)) * 20 * s
                    Circle()
                        .stroke(color, lineWidth: 0.2 * s)
                        .frame(width: 2 * 3 * s, height: 2 * 3 * s)
                        .position(x: x, y: y)
                }
            }
            .rotationEffect(rotation + .degrees(spinAddDegrees))
            .onAppear { startContinuousSpin() }
            .onChange(of: spinToken) { _, _ in
                // Quick but smooth ease-out spin of +360°
                withAnimation(.easeInOut(duration: 1.00)) {
                    let bounded = spinAddDegrees.truncatingRemainder(dividingBy: 360)
                    spinAddDegrees = bounded + 1
                }
                // Ensure the continuous spin remains active after the quick spin
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) {
                    startContinuousSpin()
                }
            }
            .allowsHitTesting(false)
        }
        .frame(minWidth: 1, minHeight: 1)
    }
}

#Preview {
    ZStack {
        AppColors.peacockBackground.ignoresSafeArea()
        OnboardingMandalaView()
            .frame(width: 192, height: 192)
    }
}


