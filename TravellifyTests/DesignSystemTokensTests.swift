import Testing
import SwiftUI
import UIKit
@testable import Travellify

@Suite("Design System — Tokens")
struct DesignSystemTokensTests {

    @Test("DSColor.Accent.primary is the Figma #0091FF blue")
    func accentPrimaryMatchesFigma() {
        // UIColor round-trip is the most-portable channel inspection across
        // iOS 17+ SDKs (Color.resolve(in:) is available but adds environment
        // wiring; UIColor(_:) is direct and lossless for sRGB inputs).
        let ui = UIColor(DSColor.Accent.primary)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)

        #expect(abs(r - 0x00 / 255.0) < 0.01)
        #expect(abs(g - 0x91 / 255.0) < 0.01)
        #expect(abs(b - 0xFF / 255.0) < 0.01)
        #expect(abs(a - 1.0) < 0.01)
    }

    @Test("Typography scale exposes all five roles with the Figma sizes")
    func typographyScaleExists() {
        #expect(DSTypography.largeTitle.size == 34)
        #expect(DSTypography.title2.size == 22)
        #expect(DSTypography.headline.size == 17)
        #expect(DSTypography.subheadline.size == 15)
        #expect(DSTypography.bodyControl.size == 17)
    }

    @Test("Spacing scale is monotonic 4→32")
    func spacingScaleIsMonotonic() {
        let scale: [CGFloat] = [
            DSSpacing.s4, DSSpacing.s8, DSSpacing.s12,
            DSSpacing.s16, DSSpacing.s20, DSSpacing.s24, DSSpacing.s32
        ]
        #expect(scale == scale.sorted())
        #expect(scale.first == 4)
        #expect(scale.last == 32)
    }

    @Test("Radius pill is large enough to fully round any practical control")
    func pillRadiusRoundsFully() {
        #expect(DSRadius.pill >= 999)
        #expect(DSRadius.card == 12)
        #expect(DSRadius.sheet == 16)
    }

    @Test("Glass shadow matches Figma rgba(0,0,0,0.12) y=8 blur=40")
    func glassShadowValues() {
        #expect(DSShadow.glass.xOffset == 0)
        #expect(DSShadow.glass.yOffset == 8)
        #expect(DSShadow.glass.blur == 40)
    }
}
