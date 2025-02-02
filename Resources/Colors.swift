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
    static let lightCharcoal = RGB (R: 96, G: 101, B: 105).color
    static let darkCharcoal = RGB(R: 68, G: 72, B: 75).color
    static let charcoalBackground = LinearGradient(colors: [lightCharcoal, darkCharcoal], startPoint: .top, endPoint: .bottom)
}
