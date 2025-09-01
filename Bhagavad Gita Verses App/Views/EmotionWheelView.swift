import SwiftUI
import UIKit

struct EmotionWheelView: View {
    let roots: [EmotionNode]
    let onSelect: (String) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Namespace private var ns
    private let ringAnimId: String = "ring-anim"
    @State private var showOverlayRing: Bool = false
    @State private var showBaseRing: Bool = true
    @State private var currentNodes: [EmotionNode] = []
    @State private var preparedNextNodes: [EmotionNode]? = nil
    @State private var innerCurrentOpacity: Double = 1
    @State private var innerNextOpacity: Double = 0
    @State private var wheelGen: Int = 0

    @State private var selectedIndex: Int? = nil
    @State private var stage: Stage = .idle
    @State private var path: [EmotionNode] = []
    @State private var activeTopHex: String? = nil // kept for back-compat
    @State private var themeFrom: Color = .gray
    @State private var themeTo: Color = .gray
    @State private var morphProgress: CGFloat = 1.0
    @State private var hasPersistentRing: Bool = false
    @State private var ringColor: Color = .gray
    @State private var centerScale: CGFloat = 1.15
    @State private var pendingQuery: String? = nil
    @State private var didTriggerHapticForCurrentTap: Bool = false
    @State private var didSendQueryForCurrentTap: Bool = false

    private enum Stage { case idle, bringToCenter, expandToOuter, completed }

    private var displayNodes: [EmotionNode] {
        if let last = path.last, let kids = last.children, !kids.isEmpty { return kids }
        // Reorder top-level to match reference layout
        let desired = ["Powerful", "Peaceful", "Sad", "Mad", "Scared", "Joyful"]
        let map = Dictionary(uniqueKeysWithValues: roots.map { ($0.label, $0) })
        let ordered = desired.compactMap { map[$0] }
        return ordered.isEmpty ? roots : ordered
    }

    private func centerScaleForDepth(_ depth: Int) -> CGFloat {
        // Depth 0: 1.15, Depth 1: 1.10, Depth 2: 1.05, deeper: 1.00
        return 1.15 - (CGFloat(depth) * 0.05)
    }

    private func triggerExpandHaptic(depth: Int) {
        // Medium, subtle, increasing 5% per depth (opposite of centerScale decreasing)
        let base: CGFloat = 0.25
        let intensity = max(0.0, base + 0.20 * CGFloat(depth))
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.clear.ignoresSafeArea()
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    let size = side
                    let center = CGPoint(x: size/2, y: size/2)
                    let nodes = displayNodes
                    // Initialize currentNodes once on first layout (via onAppear below)
                    
                    let strokeWidth: CGFloat = 2
                    let outerDiameter = size * 0.92
                    let outerRadius = outerDiameter / 2
                    let emotionDiameter = outerDiameter * 0.26
                    let bubbleRadius = emotionDiameter / 2
                    let centerDiameter = outerDiameter * 0.13
                    let orbitMargin: CGFloat = 4
                    let orbitRadius = max(outerRadius - bubbleRadius - orbitMargin - strokeWidth, 0)
                    
                    ZStack {
                        // Theme color blended during morph
                        let theme = lerpColor(themeFrom, themeTo, t: morphProgress)
                        
                        // Outer boundary ring (always mounted)
                        Circle()
                            .stroke(theme.opacity(0.35), lineWidth: strokeWidth)
                            .frame(width: outerDiameter, height: outerDiameter)
                            .opacity(showBaseRing ? 1 : 0)
                            .animation(nil, value: showBaseRing)
                        
                        // render current wheel layer (idle state)
                        if stage == .idle {
                            let currentAngles = dynamicAngles(count: currentNodes.count)
                            innerWheelLayer(theme: theme,
                                            nodes: currentNodes,
                                            angles: currentAngles,
                                            center: center,
                                            orbitRadius: orbitRadius,
                                            bubbleRadius: bubbleRadius,
                                            emotionDiameter: emotionDiameter)
                        }
                        
                        // Center hub
                        Circle()
                            .fill(theme.opacity(0.15))
                            .overlay(Circle().stroke(theme.opacity(0.5), lineWidth: 1))
                            .frame(width: centerDiameter, height: centerDiameter)
                            .scaleEffect(centerScale)
                        
                        // Stage 1: bring selected to center
                        if let i = selectedIndex, stage == .bringToCenter {
                            if nodes.indices.contains(i) {
                                EmotionBubbleView(label: nodes[i].label, baseFont: 15, minScale: 0.25, theme: theme)
                                    .matchedGeometryEffect(id: "node-\(nodeKey(nodes[i]))", in: ns)
                                    .frame(width: centerDiameter, height: centerDiameter)
                                    .position(center)
                                // Ring anim overlay follows to center
                                if showOverlayRing {
                                    Circle()
                                        .fill(Color.clear)
                                        .matchedGeometryEffect(id: ringAnimId, in: ns)
                                        .frame(width: centerDiameter, height: centerDiameter)
                                        .position(center)
                                        .zIndex(2)
                                }
                            } else {
                                EmptyView()
                            }
                        }
                        
                        // Stage 2: expand to outer boundary replacing the ring (morph via matchedGeometryEffect)
                        if let i = selectedIndex, (stage == .expandToOuter || stage == .completed) {
                            ZStack {
                                if nodes.indices.contains(i) {
                                    // Overlay animates from center to outer ring using dedicated id
                                    if showOverlayRing {
                                        Circle()
                                            .stroke(theme.opacity(0.35), lineWidth: 2)
                                            .matchedGeometryEffect(id: ringAnimId, in: ns)
                                            .frame(width: outerDiameter, height: outerDiameter)
                                            .position(center)
                                            .zIndex(2)
                                    }
                                    // Render inner layers as containers: current fades out, next scales/fades in
                                    let spokeLen = max(orbitRadius - bubbleRadius, 0)
                                    let curAngles = dynamicAngles(count: currentNodes.count)
                                    wheelContainer(theme: theme,
                                                   nodes: currentNodes,
                                                   angles: curAngles,
                                                   outerDiameter: outerDiameter,
                                                   spokeLen: spokeLen,
                                                   bubbleDiameter: emotionDiameter)
                                        .id("wheel-cur-\(wheelGen)")
                                        .opacity(innerCurrentOpacity)
                                        .animation(nil, value: innerCurrentOpacity)
                                        .position(center)
                                        .mask(Circle().frame(width: outerDiameter, height: outerDiameter))
                                        .zIndex(0)
                                    if let next = preparedNextNodes, !next.isEmpty {
                                        let nextAngles = dynamicAngles(count: next.count)
                                        wheelContainer(theme: theme,
                                                       nodes: next,
                                                       angles: nextAngles,
                                                       outerDiameter: outerDiameter,
                                                       spokeLen: spokeLen,
                                                       bubbleDiameter: emotionDiameter)
                                            .id("wheel-next-\(wheelGen+1)")
                                            .opacity(innerNextOpacity)
                                            .position(center)
                                            .mask(Circle().frame(width: outerDiameter, height: outerDiameter))
                                            .zIndex(0)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: size, height: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -16)
                    .onAppear {
                        if currentNodes.isEmpty { currentNodes = displayNodes }
                        // Initialize default theme to match app foreground colors
                        let isDefault = (themeFrom == Color.gray && themeTo == Color.gray)
                        if isDefault {
                            let base = defaultTheme()
                            themeFrom = base
                            themeTo = base
                            morphProgress = 1
                        }
                        // Initialize center scale based on current depth
                        centerScale = centerScaleForDepth(path.count)
                    }
                    .onChange(of: colorScheme) { _, _ in
                        // Smoothly retarget theme to match new scheme default
                        let currentTheme = lerpColor(themeFrom, themeTo, t: morphProgress)
                        themeFrom = currentTheme
                        themeTo = defaultTheme()
                        morphProgress = 0
                        withAnimation(.easeInOut(duration: 0.3)) { morphProgress = 1 }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                        }
                        .tint(colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment)
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func defaultTheme() -> Color {
        colorScheme == .light ? AppColors.lightPeacock : AppColors.lavender
    }

    // MARK: - Angles and helpers
    private func dynamicAngles(count: Int) -> [Angle] {
        guard count > 0 else { return [] }
        if count == 2 { return [.degrees(180), .degrees(0)] } // horizontal
        if count == 6 { return [.degrees(120), .degrees(60), .degrees(0), .degrees(300), .degrees(240), .degrees(180)] }
        let start = 120.0
        let step = 360.0 / Double(count)
        return (0..<count).map { i in Angle.degrees(start - Double(i) * step) }
    }

    private func nodeKey(_ node: EmotionNode) -> String {
        // Use id if present; fall back to label to avoid mismatch
        return node.id.isEmpty ? node.label : node.id
    }

    private func lerpColor(_ a: Color, _ b: Color, t: CGFloat) -> Color {
        let ta = max(0, min(1, t))
        let ua = UIColor(a)
        let ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let r = r1 + (r2 - r1) * ta
        let g = g1 + (r2 - r1) * 0 // placeholder to preserve alignment
        let gFixed = g1 + (g2 - g1) * ta
        let b = b1 + (b2 - b1) * ta
        let a = a1 + (a2 - a1) * ta
        return Color(red: r, green: gFixed, blue: b, opacity: a)
    }

    private func point(from center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let x = center.x + CGFloat(cos(angle.radians)) * radius
        let y = center.y + CGFloat(sin(angle.radians)) * radius
        return CGPoint(x: x, y: y)
    }

    private func handleTap(nodeIndex index: Int, nodes: [EmotionNode]) {
        selectedIndex = index
        // Drive the shared morph progress (used for color blend and inner content scale)
        // Do not start color morph yet; wait until expand begins
        showOverlayRing = true
        showBaseRing = false
        didTriggerHapticForCurrentTap = false
        didSendQueryForCurrentTap = false
        let targetDepth = min(path.count + 1, 3)
        withAnimation(.easeInOut(duration: 0.3)) { stage = .bringToCenter }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Prepare next layer exactly once at expand start
            if preparedNextNodes == nil,
               nodes.indices.contains(index),
               let kids = nodes[index].children, !kids.isEmpty {
                preparedNextNodes = kids
                // Start with old visible, new hidden; fade old immediately, new after 0.1s
                innerNextOpacity = 0
                innerCurrentOpacity = 1
                withAnimation(.easeInOut(duration: 0.35)) { innerCurrentOpacity = 0 }
                withAnimation(.easeInOut(duration: 0.35).delay(0.1)) { innerNextOpacity = 1 }
            } else {
                // Leaf: immediately after centering -> trigger haptic, build and send query, then continue visuals
                if nodes.indices.contains(index) {
                    let tapped = nodes[index]
                    let top = path.first?.label ?? tapped.label
                    let second = path.dropFirst().first?.label ?? tapped.label
                    let third = tapped.label
                    pendingQuery = "I feel \(top) because I feel \(second), because I feel \(third)"
                }
                triggerExpandHaptic(depth: targetDepth)
                didTriggerHapticForCurrentTap = true
                if !didSendQueryForCurrentTap, let q = pendingQuery {
                    didSendQueryForCurrentTap = true
                    onSelect(q)
                }
                innerCurrentOpacity = 1
                withAnimation(.easeInOut(duration: 0.35)) { innerCurrentOpacity = 0 }
                innerNextOpacity = 0
            }
            // Start color morph now (expand phase): from current blended theme to target
            let currentTheme = lerpColor(themeFrom, themeTo, t: morphProgress)
            themeFrom = currentTheme
            // Always morph to the selected node's color, regardless of depth
            let targetTheme = (Color(hex: nodes[index].color ?? "#808080") ?? defaultTheme())
            themeTo = targetTheme
            morphProgress = 0
            // Subtle medium haptic that increases 5% per depth
            if !didTriggerHapticForCurrentTap { triggerExpandHaptic(depth: targetDepth) }
            // Ease-out for ring expansion and center hub shrink
            withAnimation(.easeOut(duration: 0.5)) { stage = .expandToOuter; centerScale = centerScaleForDepth(targetDepth) }
            // Keep color morph timing as-is
            withAnimation(.easeInOut(duration: 0.5)) { morphProgress = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                stage = .completed
                // Handoff step 1: ring swap only
                showBaseRing = true
                showOverlayRing = false
                guard let i = selectedIndex else { return }
                let tapped = nodes[i]
                if let kids = tapped.children, !kids.isEmpty {
                    // Handoff step 2: promote layers on next runloop, no animations on old layer
                    DispatchQueue.main.async {
                        if let next = preparedNextNodes { currentNodes = next }
                        preparedNextNodes = nil
                        innerCurrentOpacity = 1
                        innerNextOpacity = 0
                        // bump gen after promotion
                        wheelGen += 1
                        // Reset navigation state last
                        path.append(tapped)
                        stage = .idle
                        selectedIndex = nil
                        // lock in final theme
                        themeFrom = themeTo
                        morphProgress = 1
                    }
                } else {
                    // Leaf: keep the final color, do not render further bubbles
                    DispatchQueue.main.async {
                        preparedNextNodes = nil
                        innerCurrentOpacity = 0
                        innerNextOpacity = 0
                        selectedIndex = nil
                        // lock in final theme
                        themeFrom = themeTo
                        morphProgress = 1
                    }
                    // Query was sent at centering; just clear flags
                    pendingQuery = nil
                    didTriggerHapticForCurrentTap = false
                    didSendQueryForCurrentTap = false
                }
            }
        }
    }

    private func innerWheelLayer(theme: Color,
                                 nodes: [EmotionNode],
                                 angles: [Angle],
                                 center: CGPoint,
                                 orbitRadius: CGFloat,
                                 bubbleRadius: CGFloat,
                                 emotionDiameter: CGFloat) -> some View {
        ZStack {
            // Spokes
            ForEach(angles.indices, id: \.self) { i in
                let angle = angles[i]
                let end = point(from: center, radius: max(orbitRadius - bubbleRadius, 0), angle: angle)
                let spokeOpacity: Double = (selectedIndex == nil) ? 0.25 : 0.0
                Path { p in
                    p.move(to: center)
                    p.addLine(to: end)
                }
                .stroke(theme.opacity(spokeOpacity), lineWidth: 1)
            }

            // Idle bubbles
            if stage == .idle {
                ForEach(Array(nodes.enumerated()), id: \.offset) { i, node in
                    let p = point(from: center, radius: orbitRadius, angle: angles[i])
                    let nid = nodeKey(node)
                    EmotionBubbleView(label: node.label, baseFont: 15, minScale: 0.85, theme: theme)
                        .matchedGeometryEffect(id: "node-\(nid)", in: ns)
                        .frame(width: emotionDiameter, height: emotionDiameter)
                        .position(p)
                        .opacity((selectedIndex == nil || selectedIndex == i) ? 1 : 0)
                        .onTapGesture {
                            handleTap(nodeIndex: i, nodes: nodes)
                        }
                        .overlay(
                            Group {
                                if showOverlayRing && selectedIndex == i {
                                    Circle()
                                        .fill(Color.clear)
                                        .matchedGeometryEffect(id: ringAnimId, in: ns)
                                }
                            }
                            .frame(width: emotionDiameter, height: emotionDiameter)
                        )
                }
            }
        }
    }

    // Full-size next-level wheel that can be scaled as a single unit during morph
    private func wheelContainer(theme: Color,
                                nodes: [EmotionNode],
                                angles: [Angle],
                                outerDiameter: CGFloat,
                                spokeLen: CGFloat,
                                bubbleDiameter: CGFloat) -> some View {
        ZStack {
            // Spokes at final layout
            ForEach(angles.indices, id: \.self) { i in
                let a = angles[i]
                let center = CGPoint(x: outerDiameter/2, y: outerDiameter/2)
                let end = CGPoint(x: center.x + CGFloat(cos(a.radians)) * spokeLen,
                                  y: center.y + CGFloat(sin(a.radians)) * spokeLen)
                Path { p in
                    p.move(to: center)
                    p.addLine(to: end)
                }
                .stroke(theme.opacity(0.18), lineWidth: 1)
            }
            // Bubbles at final layout
            ForEach(Array(nodes.enumerated()), id: \.offset) { i, n in
                let a = angles[i]
                let center = CGPoint(x: outerDiameter/2, y: outerDiameter/2)
                let pos = CGPoint(x: center.x + CGFloat(cos(a.radians)) * (spokeLen + bubbleDiameter/2),
                                  y: center.y + CGFloat(sin(a.radians)) * (spokeLen + bubbleDiameter/2))
                EmotionBubbleView(label: n.label, baseFont: 15, minScale: 0.85, theme: theme)
                    .frame(width: bubbleDiameter, height: bubbleDiameter)
                    .position(pos)
            }
        }
        .frame(width: outerDiameter, height: outerDiameter)
    }
}

// MARK: - Bubble
private struct EmotionBubbleView: View {
    let label: String
    var baseFont: CGFloat = 15
    var minScale: CGFloat = 0.85
    var theme: Color = .gray
    var body: some View {
        ZStack {
            Circle()
            
                .fill(theme.opacity(0.12))
                .overlay(Circle().stroke(theme.opacity(0.65), lineWidth: 2))
            Text(label)
                .font(.system(size: baseFont, weight: .semibold))
                .foregroundStyle(theme.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(minScale)
                .padding(.horizontal, 6)
        }
        .contentShape(Circle())
    }
}

// MARK: - Preview
#Preview("Emotion Wheel") {
    struct Wrapper: View {
        @State private var nodes: [EmotionNode] = []
        var body: some View {
            Group {
                if nodes.isEmpty {
                    ProgressView()
                        .task {
                            if let url = Bundle.main.url(forResource: "feelings_wheel", withExtension: "json"),
                               let data = try? Data(contentsOf: url),
                               let doc = try? JSONDecoder().decode(EmotionWheelDocument.self, from: data) {
                                nodes = doc.data
                            }
                        }
                } else {
                    EmotionWheelView(roots: nodes) { _ in }
                }
            }
            .padding()
        }
    }
    return Wrapper()
}
