import SwiftUI

/// A shadow specification: offset, blur radius, and color.
struct DSShadowSpec: Equatable {
    let xOffset: CGFloat
    let yOffset: CGFloat
    let blur: CGFloat
    let color: Color
}

/// Shadow tokens sourced from Figma node 93:132.
enum DSShadow {
    /// rgba(0,0,0,0.12), y=8, blur=40 — applied to liquid-glass surfaces.
    static let glass = DSShadowSpec(
        xOffset: 0,
        yOffset: 8,
        blur: 40,
        color: Color.black.opacity(0.12)
    )
}

extension View {
    /// Applies a `DSShadowSpec` token via SwiftUI's `.shadow` modifier.
    func dsShadow(_ spec: DSShadowSpec) -> some View {
        shadow(
            color: spec.color,
            radius: spec.blur,
            x: spec.xOffset,
            y: spec.yOffset
        )
    }
}
