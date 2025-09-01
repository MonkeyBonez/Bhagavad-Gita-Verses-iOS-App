import SwiftUI

public struct ActionIconButton: View {
    let systemName: String
    let height: CGFloat
    let padding: CGFloat
    let onTap: () -> Void
    @State private var scale: CGFloat = 1.0

    public init(systemName: String, height: CGFloat = 26, padding: CGFloat = 30, onTap: @escaping () -> Void) {
        self.systemName = systemName
        self.height = height
        self.padding = padding
        self.onTap = onTap
    }

    public var body: some View {
        Image(systemName: systemName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .padding(padding)
            .contentShape(Rectangle())
            .scaleEffect(scale)
            .simultaneousGesture(TapGesture().onEnded {
                scale = 0.9
                withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
                    scale = 1.0
                }
                onTap()
            })
    }
}



