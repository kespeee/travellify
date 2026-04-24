import SwiftUI

/// Pill-shaped CTA matching the Figma "Button - Liquid Glass - Text" component
/// (node 93:132 / I96:1726). Uses SwiftUI default Button + .borderedProminent +
/// .tint — Apple handles label color and press state.
struct LiquidGlassButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    init(
        _ title: String,
        tint: Color = DSColor.Accent.primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
    }
}

#if DEBUG
#Preview {
    LiquidGlassButton("Create a trip") {}
        .padding()
        .background(DSColor.Background.primary)
}
#endif
