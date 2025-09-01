import SwiftUI
import UIKit

struct ColorPickerSheetView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedColor: Color
    @State private var showUIKitPicker: Bool = false
    @State private var selectedEmotionKey: String? = nil
    let onPick: (Color) -> Void
    let onClose: () -> Void
    let onSubmitQuery: ((String) -> Void)?

    private let engine = ColorEmotionEngine()

    init(initialColor: Color = .blue,
         onPick: @escaping (Color) -> Void,
         onClose: @escaping () -> Void,
         onSubmitQuery: ((String) -> Void)? = nil) {
        self._selectedColor = State(initialValue: initialColor)
        self.onPick = onPick
        self.onClose = onClose
        self.onSubmitQuery = onSubmitQuery
    }

    private var background: some View {
        colorScheme == .light ? AppColors.parchment.linearGradient : AppColors.peacockBackground
    }

    private var foregroundColor: Color {
        colorScheme == .light ? AppColors.lightPeacock : AppColors.parchment
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Visible preview circle (non-interactive)
                Circle()
                    .fill(selectedColor)
                    .overlay(Circle().stroke(foregroundColor.opacity(0.5), lineWidth: 2))
                    .frame(width: 160, height: 160)
                    .padding(.top, 8)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: colorScheme == .dark ? 10 : 12, x: 0, y: colorScheme == .dark ? 6 : 8)
                    .onTapGesture { showUIKitPicker = true }

                // Compute emotions for current color
                let result = engine.evaluate(color: selectedColor)
                let top3 = Array(result.top5.prefix(3))

                // Top 3 selectable options (single selection)
                if !top3.isEmpty {
                    if #available(iOS 26.0, *) {
                        LiquidGlassSegmentedPicker(
                            items: top3.map { $0.0.capitalized },
                            selection: Binding<String>(
                                get: { (selectedEmotionKey ?? top3.first?.0)?.capitalized ?? top3[0].0.capitalized },
                                set: { selectedEmotionKey = $0.lowercased() }
                            ),
                            tint: foregroundColor,
                            selectedTextColor: (colorScheme == .light ? AppColors.lavender : AppColors.greenPeacock),
                            selectedPillTint: (colorScheme == .light ? AppColors.greenPeacock : .indigo)
                        )
                        .padding(.horizontal)
                    } else {
                        HStack(spacing: 20) {
                            ForEach(top3, id: \.0) { item in
                                let emotion = item.0
                                let isSelected = (selectedEmotionKey ?? top3.first?.0) == emotion
                                Button(action: { selectedEmotionKey = emotion }) {
                                    Text(emotion.capitalized)
                                        .font(.subheadline)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 36)
                                        .background(
                                            Capsule().fill(
                                                isSelected
                                                ? (colorScheme == .dark ? AppColors.lavender : foregroundColor.opacity(0.95))
                                                : Color.clear
                                            )
                                        )
                                        .overlay(
                                            Capsule().stroke(foregroundColor.opacity(0.6), lineWidth: 1)
                                        )
                                        .foregroundStyle(isSelected ? (colorScheme == .light ? AppColors.lavender : AppColors.greenPeacock) : foregroundColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { onClose() }) {
                        Image(systemName: "xmark")
                    }
                    .tint(foregroundColor)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button(action: {
                            if let key = selectedEmotionKey {
                                onSubmitQuery?("I feel \(key.capitalized)")
                            }
                            onPick(selectedColor)
                            onClose()
                        }) {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.glassProminent)
                        .tint(AppColors.vividPurple)
                    } else {
                        Button(action: {
                            if let key = selectedEmotionKey {
                                onSubmitQuery?("I feel \(key.capitalized)")
                            }
                            onPick(selectedColor)
                            onClose()
                        }) {
                            Image(systemName: "checkmark")
                        }
                        .tint(foregroundColor)
                    }
                }
            }
            .sheet(isPresented: $showUIKitPicker) {
                UIKitColorPickerView(color: $selectedColor, isPresented: $showUIKitPicker, supportsAlpha: false)
            }
            .onAppear {
                // Default selected emotion = top1 for initial color
                let initialTop = engine.evaluate(color: selectedColor).top5.first?.0
                if selectedEmotionKey == nil { selectedEmotionKey = initialTop }
            }
            .onChange(of: selectedColor) { newColor in
                // When color changes, default selection back to new top emotion
                selectedEmotionKey = engine.evaluate(color: newColor).top5.first?.0
            }
        }
        .background(background.ignoresSafeArea())
    }
}

#if canImport(UIKit)
@available(iOS 26.0, *)
private struct LiquidGlassSegmentedPicker: View {
    let items: [String]
    @Binding var selection: String
    var tint: Color
    var selectedTextColor: Color
    var selectedPillTint: Color

    @Namespace private var ns

    var body: some View {
        HStack(spacing: 20) {
            ForEach(items, id: \.self) { label in
                let isSelected = label == selection
                Button(action: {
                    withAnimation(.smooth(duration: 0.25)) {
                        selection = label
                    }
                }) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isSelected ? .clear : tint)
                .overlay(
                    Group {
                        if isSelected {
                            Capsule()
                                .glassEffect(.regular.tint(selectedPillTint.opacity(0.4)))
                                .overlay(Text(label)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 36)
                                    .contentShape(Rectangle())
                                    .foregroundStyle(selectedTextColor)
                                    .allowsHitTesting(false)
                                )
                                .matchedGeometryEffect(id: "lg-pill", in: ns)
                        }
                    }
                )
                .overlay {
                    if !isSelected {
                        Capsule().stroke(tint.opacity(0.6), lineWidth: 1)
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: selection)
    }
}

private struct UIKitColorPickerView: UIViewControllerRepresentable {
    @Binding var color: Color
    @Binding var isPresented: Bool
    var supportsAlpha: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.delegate = context.coordinator
        picker.supportsAlpha = supportsAlpha
        picker.selectedColor = UIColor(color)
        return picker
    }

    func updateUIViewController(_ uiViewController: UIColorPickerViewController, context: Context) {
        // Keep UIKit picker in sync if SwiftUI color changes externally
        if uiViewController.selectedColor != UIColor(color) {
            uiViewController.selectedColor = UIColor(color)
        }
        uiViewController.supportsAlpha = supportsAlpha
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        var parent: UIKitColorPickerView

        init(_ parent: UIKitColorPickerView) {
            self.parent = parent
        }

        func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
            parent.color = Color(uiColor: viewController.selectedColor)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            parent.color = Color(uiColor: viewController.selectedColor)
            parent.isPresented = false
        }
    }
}
#endif

#Preview("Color Picker Sheet") {
    ColorPickerSheetView(initialColor: .blue, onPick: { _ in }, onClose: {})
}
