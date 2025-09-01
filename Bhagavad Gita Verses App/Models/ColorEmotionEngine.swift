import SwiftUI
import CoreGraphics
import simd

public struct EmotionKernel { public let center: SIMD3<Double>; public let spreads: SIMD3<Double> }
public struct PAD { public let v: Double; public let a: Double; public let d: Double }
public struct EngineResult {
    public let pad: PAD
    public let probs: [String: Double]
    public let top5: [(String, Double)]
    public let family: String
}

public struct ColorEmotionEngine {
    // MARK: configuration
    private let squashCenter = 0.35
    private let squashK = 4.2

    private var kernels: [String: EmotionKernel] = [
        "anger": EmotionKernel(center: .init(0.18, 0.86, 0.72), spreads: .init(0.22, 0.14, 0.20)),
        "anxious": EmotionKernel(center: .init(0.20, 0.78, 0.50), spreads: .init(0.18, 0.16, 0.18)),
        "fear": EmotionKernel(center: .init(0.15, 0.82, 0.40), spreads: .init(0.18, 0.16, 0.18)),
        "jealousy": EmotionKernel(center: .init(0.22, 0.66, 0.55), spreads: .init(0.20, 0.18, 0.18)),
        "envy": EmotionKernel(center: .init(0.28, 0.62, 0.52), spreads: .init(0.20, 0.18, 0.18)),
        "sad": EmotionKernel(center: .init(0.14, 0.22, 0.30), spreads: .init(0.14, 0.16, 0.16)),
        "tired": EmotionKernel(center: .init(0.28, 0.18, 0.28), spreads: .init(0.18, 0.18, 0.18)),
        "boredom": EmotionKernel(center: .init(0.33, 0.15, 0.35), spreads: .init(0.08, 0.14, 0.14)),
        "shame": EmotionKernel(center: .init(0.20, 0.35, 0.28), spreads: .init(0.20, 0.18, 0.18)),
        "disgust": EmotionKernel(center: .init(0.25, 0.40, 0.40), spreads: .init(0.20, 0.18, 0.18)),
        "calm": EmotionKernel(center: .init(0.74, 0.30, 0.45), spreads: .init(0.14, 0.14, 0.14)),
        "relaxed": EmotionKernel(center: .init(0.70, 0.28, 0.46), spreads: .init(0.14, 0.14, 0.14)),
        "content": EmotionKernel(center: .init(0.72, 0.34, 0.48), spreads: .init(0.10, 0.12, 0.10)),
        "gratitude": EmotionKernel(center: .init(0.78, 0.36, 0.50), spreads: .init(0.16, 0.16, 0.16)),
        "hope": EmotionKernel(center: .init(0.76, 0.44, 0.52), spreads: .init(0.16, 0.16, 0.16)),
        "joy": EmotionKernel(center: .init(0.90, 0.70, 0.60), spreads: .init(0.10, 0.12, 0.12)),
        "amusement": EmotionKernel(center: .init(0.82, 0.64, 0.50), spreads: .init(0.16, 0.16, 0.16)),
        "love": EmotionKernel(center: .init(0.80, 0.60, 0.48), spreads: .init(0.16, 0.16, 0.16)),
        "awe": EmotionKernel(center: .init(0.72, 0.68, 0.42), spreads: .init(0.10, 0.10, 0.12)),
        "pride": EmotionKernel(center: .init(0.74, 0.62, 0.60), spreads: .init(0.18, 0.18, 0.18)),
        "nostalgia": EmotionKernel(center: .init(0.60, 0.32, 0.45), spreads: .init(0.09, 0.09, 0.10))
    ]

    private var gewPriors: [String: [String: Double]] = [
        "red": ["anger":0.62, "love":0.16, "excitement":0.16, "pride":0.04, "fear":0.01, "anxious":0.01],
        "orange": ["joy":0.32, "amusement":0.22, "gratitude":0.20, "hope":0.12, "content":0.14],
        "yellow": ["joy":0.42, "amusement":0.22, "gratitude":0.18, "hope":0.10, "content":0.08],
        "yellow_green": ["calm":0.30, "content":0.24, "envy":0.18, "jealousy":0.16, "hope":0.12],
        "green": ["calm":0.36, "content":0.20, "relaxed":0.22, "envy":0.12, "jealousy":0.10],
        "cyan": ["calm":0.34, "content":0.22, "hope":0.22, "awe":0.10, "pride":0.12],
        "blue": ["calm":0.34, "content":0.22, "hope":0.20, "awe":0.10, "pride":0.14],
        "purple": ["love":0.26, "pride":0.26, "awe":0.18, "joy":0.16, "amusement":0.14],
        "magenta": ["love":0.34, "joy":0.30, "amusement":0.20, "gratitude":0.10, "pride":0.06],
        "brown": ["disgust":0.28, "boredom":0.18, "tired":0.18, "nostalgia":0.20, "shame":0.16],
        "olive": ["envy":0.30, "jealousy":0.28, "disgust":0.20, "boredom":0.12, "nostalgia":0.10],
        "gray_black": ["sad":0.30, "tired":0.24, "anxious":0.16, "anger":0.16, "boredom":0.14],
        "white": ["hope":0.30, "gratitude":0.30, "calm":0.24, "content":0.10, "joy":0.06]
    ]

    private let diversityCap = 0.45
    private let diversityWeights: [String: Double] = [
        "jealousy":2.0, "envy":2.0, "shame":2.0, "disgust":2.0, "pride":1.6, "boredom":1.6,
        "hope":1.2, "fear":1.2
    ]

    private let gammaAll: Double = 0.004
    private let gammaPer: [String: Double] = [
        "jealousy":0.028, "envy":0.028, "shame":0.028, "disgust":0.028, "pride":0.020,
        "fear":0.028, "hope":0.028, "gratitude":0.020, "love":0.028, "awe":0.028,
        "boredom":0.028, "tired":0.028
    ]

    public init() {
        gewPriors = gewPriors.mapValues { dist in
            var merged = dist
            for e in kernels.keys where merged[e] == nil { merged[e] = 0.0001 }
            let s = merged.values.reduce(0,+)
            var norm = merged.mapValues { $0 / s }
            if let (maxE, maxV) = norm.max(by: { $0.value < $1.value }), maxV > diversityCap {
                let excess = maxV - diversityCap
                norm[maxE] = diversityCap
                let totalW = norm.reduce(0.0) { partial, kv in
                    let e = kv.key
                    return partial + (e == maxE ? 0.0 : (diversityWeights[e] ?? 1.0))
                }
                for (e, v) in norm {
                    if e == maxE { continue }
                    let w = (diversityWeights[e] ?? 1.0)
                    norm[e] = v + excess * (w / max(totalW, 1e-9))
                }
                let s2 = norm.values.reduce(0,+)
                norm = norm.mapValues { $0 / s2 }
            }
            return norm
        }
    }

    public func evaluate(color: Color) -> EngineResult {
        let rgb = ceRgbFromColor(color)
        let hsv = CE_HSV.fromSRGB(rgb)
        let lab = CE_LabColor.fromSRGB(rgb)
        let Lnorm = lab.L / 100.0

        var P = 0.69 * Lnorm + 0.22 * hsv.s
        var A = -0.31 * Lnorm + 0.60 * hsv.s
        var D = -0.76 * Lnorm + 0.32 * hsv.s
        P = logistic(P)
        A = logistic(A)
        D = logistic(D)
        let pad = PAD(v: P, a: A, d: D)

        var scores: [String: Double] = [:]
        for (name, k) in kernels {
            let x = SIMD3<Double>(P, A, D)
            let mu = k.center
            let dx = (x.x - mu.x) / k.spreads.x
            let dy = (x.y - mu.y) / k.spreads.y
            let dz = (x.z - mu.z) / k.spreads.z
            let m2 = 0.5 * (dx*dx + dy*dy + dz*dz)
            scores[name] = exp(-m2)
        }

        let bin = hueBin(hsv: hsv, L: lab.L)
        if let prior = gewPriors[bin] {
            for (e, pv) in prior { scores[e] = (scores[e] ?? 0) * pv }
        }

        if hsv.s < 0.10 {
            if lab.L < 35 {
                for e in ["sad","tired","anxious","anger"] { scores[e] = (scores[e] ?? 0) * 1.15 }
            } else if lab.L < 70 {
                scores["boredom"] = (scores["boredom"] ?? 0) * 0.80
                for e in ["sad","tired","shame","disgust"] { scores[e] = (scores[e] ?? 0) * 1.05 }
            } else {
                for e in ["hope","gratitude","calm","content"] { scores[e] = (scores[e] ?? 0) * 1.08 }
            }
        }

        if bin == "red" && hsv.s >= 0.6 && lab.L >= 45 && lab.L <= 70 {
            let love = scores["love"] ?? 0
            let excite = scores["amusement"] ?? 0
            let meanLE = 0.5 * (love + excite)
            let floorRatio = 0.90
            scores["anger"] = max(scores["anger"] ?? 0, floorRatio * meanLE)
        }

        var total = scores.values.reduce(0,+)
        if total <= 0 { total = 1.0 }
        var probs = scores.mapValues { $0 / total }

        for (e, g) in gammaPer { probs[e] = (probs[e] ?? 0) + g + gammaAll }
        for e in kernels.keys where gammaPer[e] == nil { probs[e] = (probs[e] ?? 0) + gammaAll }
        let s3 = probs.values.reduce(0,+)
        probs = probs.mapValues { $0 / s3 }

        let top5 = probs.sorted(by: { $0.value > $1.value }).prefix(5).map { ($0.key, $0.value) }
        let fam = ceFamilyLabel(pad: pad)
        return EngineResult(pad: pad, probs: probs, top5: top5, family: fam)
    }

    private func logistic(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-squashK * (x - squashCenter)))
    }

    private func hueBin(hsv: CE_HSV, L: Double) -> String {
        if hsv.s < 0.10 { return L < 50 ? "gray_black" : (L > 85 ? "white" : "gray_black") }
        let h = hsv.h
        switch h {
        case 350...360, 0..<15: return "red"
        case 15..<35: return "orange"
        case 35..<65: return "yellow"
        case 65..<90: return "yellow_green"
        case 90..<150: return "green"
        case 150..<190: return "cyan"
        case 190..<255: return "blue"
        case 255..<285: return "purple"
        case 285..<325: return "magenta"
        case 325..<350: return "red"
        default: return "gray_black"
        }
    }

    public func hexString(from color: Color) -> String {
        let rgb = ceRgbFromColor(color)
        let r = Int((rgb.r * 255.0).rounded())
        let g = Int((rgb.g * 255.0).rounded())
        let b = Int((rgb.b * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r,g,b)
    }
}

// MARK: - Namespaced helper types
public struct CE_RGB { public let r: Double; public let g: Double; public let b: Double }
public struct CE_HSV { public let h: Double; public let s: Double; public let v: Double }
public struct CE_LabColor { public let L: Double; public let a: Double; public let b: Double }

public extension CE_HSV {
    static func fromSRGB(_ rgb: CE_RGB) -> CE_HSV {
        let r = rgb.r, g = rgb.g, b = rgb.b
        let mx = max(r, max(g, b)), mn = min(r, min(g, b))
        let c = mx - mn
        var h: Double = 0
        if c == 0 { h = 0 }
        else if mx == r { h = 60 * fmod(((g - b)/c), 6) }
        else if mx == g { h = 60 * (((b - r)/c) + 2) }
        else { h = 60 * (((r - g)/c) + 4) }
        if h < 0 { h += 360 }
        let v = mx
        let s = mx == 0 ? 0 : c/mx
        return CE_HSV(h: h, s: s, v: v)
    }
}

public extension CE_LabColor {
    static func fromSRGB(_ rgb: CE_RGB) -> CE_LabColor {
        func invGamma(_ u: Double) -> Double { return u <= 0.04045 ? u/12.92 : pow((u + 0.055)/1.055, 2.4) }
        let r = invGamma(rgb.r), g = invGamma(rgb.g), bl = invGamma(rgb.b)
        let X = 0.4124564*r + 0.3575761*g + 0.1804375*bl
        let Y = 0.2126729*r + 0.7151522*g + 0.0721750*bl
        let Z = 0.0193339*r + 0.1191920*g + 0.9503041*bl
        let Xn = 0.95047, Yn = 1.00000, Zn = 1.08883
        func f(_ t: Double) -> Double { let d = 6.0/29.0; return t > pow(d,3) ? cbrt(t) : (t/(3*d*d) + 4.0/29.0) }
        let fx = f(X/Xn), fy = f(Y/Yn), fz = f(Z/Zn)
        let L = 116*fy - 16
        let labA = 500*(fx - fy)
        let labB = 200*(fy - fz)
        return CE_LabColor(L: L, a: labA, b: labB)
    }
}

public func ceRgbFromColor(_ color: Color) -> CE_RGB {
    #if os(iOS)
    let ui = UIColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    return CE_RGB(r: Double(r), g: Double(g), b: Double(b))
    #else
    return CE_RGB(r: 1, g: 0, b: 0)
    #endif
}

private func ceFamilyLabel(pad: PAD) -> String {
    let valence = pad.v, arousal = pad.a
    let posNeg = valence >= 0.5 ? "positive" : "negative"
    let ar: String = arousal < 0.33 ? "low" : (arousal < 0.66 ? "mid" : "high")
    return "\(posNeg)-\(ar)"
}
