import SwiftUI

/// A typography token: name (informational), size, weight, optional line height,
/// and tracking (letter-spacing in points).
///
/// SF Pro is the iOS system font, so `Font.system(size:weight:)` is the correct
/// mapping; `name` is preserved for documentation parity with Figma.
struct DSFont: Equatable {
    let name: String
    let size: CGFloat
    let weight: Font.Weight
    /// Figma line-height in points; nil means "use system default for this size".
    let lineHeight: CGFloat?
    let tracking: CGFloat

    func font() -> Font {
        Font.system(size: size, weight: weight)
    }
}

/// Typography scale sourced from Figma node 93:132.
enum DSTypography {
    static let largeTitle = DSFont(
        name: "SF Pro",
        size: 34,
        weight: .bold,
        lineHeight: 41,
        tracking: 0.40
    )

    static let title2 = DSFont(
        name: "SF Pro",
        size: 22,
        weight: .bold,
        lineHeight: 26,
        tracking: -0.26
    )

    static let headline = DSFont(
        name: "SF Pro",
        size: 17,
        weight: .semibold,
        lineHeight: 22,
        tracking: -0.43
    )

    static let subheadline = DSFont(
        name: "SF Pro",
        size: 15,
        weight: .regular,
        lineHeight: 20,
        tracking: -0.23
    )

    static let bodyControl = DSFont(
        name: "SF Pro",
        size: 17,
        weight: .medium,
        lineHeight: nil,
        tracking: 0
    )
}

extension View {
    /// Applies a `DSFont` token: font + tracking, plus line spacing if `lineHeight`
    /// is non-nil. Line spacing approximates Figma line-height by adding the
    /// difference between the token's line height and the font's natural height.
    func dsTypography(_ token: DSFont) -> some View {
        let extra: CGFloat
        if let lineHeight = token.lineHeight {
            extra = max(0, lineHeight - token.size)
        } else {
            extra = 0
        }
        return self
            .font(token.font())
            .kerning(token.tracking)
            .lineSpacing(extra)
    }
}
