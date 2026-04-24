import SwiftUI

/// Pill-shaped CTA matching the Figma "Button - Liquid Glass - Text" component
/// (node 93:132 / I96:1726): 40pt height, 6pt vertical / 20pt horizontal padding,
/// fully rounded, 17pt SF Pro Medium label, default tint #0091FF, glass shadow.
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
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .medium))
                .padding(.vertical, 6)
                .padding(.horizontal, DSSpacing.s20)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DSColor.Label.vibrantPrimary)
        .tint(DSColor.Label.vibrantPrimary)
        .background {
            Capsule().fill(tint)
        }
        .background {
            Color.clear.liquidGlass(in: Capsule(), tint: nil)
        }
        .dsShadow(DSShadow.glass)
    }
}

#if DEBUG
#Preview {
    LiquidGlassButton("Create a trip") {}
        .padding()
        .background(DSColor.Background.primary)
}
#endif
