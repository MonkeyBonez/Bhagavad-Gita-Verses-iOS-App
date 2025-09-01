import SwiftUI

struct RGB {
    let R: CGFloat
    let G: CGFloat
    let B: CGFloat
    var color: Color {
        Color(red: R / 255.0, green: G / 255.0, blue: B / 255.0)
    }
}

struct AppColors {
    static let parchment = RGB(R: 238, G: 231, B: 210).color
    static let lavender = RGB(R: 229, G: 222, B: 252).color
    static let vividPurple = RGB(R: 100, G: 88, B: 246).color
    static let greenPeacock = RGB(R: 16, G: 34, B: 30).color
    static let bluePeacock = RGB(R: 16, G: 34, B: 34).color
    static let peacockBackground = LinearGradient(colors: [greenPeacock, bluePeacock], startPoint: .top, endPoint: .bottom)
    static let lightPeacock = RGB(R: 29, G: 62, B: 47).color
    static let parchmentSolidAsGradient = parchment.linearGradient
}

extension Color {
    var linearGradient: LinearGradient {
        LinearGradient(colors: [self, self], startPoint: .leading, endPoint: .trailing)
    }
}
