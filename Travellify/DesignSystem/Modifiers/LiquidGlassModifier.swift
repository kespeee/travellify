import SwiftUI

/// Renders a liquid-glass surface behind any content, clipped to the supplied
/// shape. On iOS 26+ it uses Apple's native `.glassEffect(_:in:)`; on iOS 17–25
/// it falls back to `.ultraThinMaterial` plus a subtle gradient overlay that
/// approximates the Figma reference (D7-05).
struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Native iOS 26 liquid glass — `Glass.regular` + optional tint.
            content.glassEffect(.regular.tint(tint), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(tintOverlay)
                .overlay(
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.black.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blendMode(.plusLighter)
                )
        }
    }

    @ViewBuilder
    private var tintOverlay: some View {
        if let tint {
            shape.fill(tint)
        }
    }
}

extension View {
    /// Apply a liquid-glass surface in the supplied shape with an optional tint.
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        modifier(LiquidGlassModifier(shape: shape, tint: tint))
    }
}
