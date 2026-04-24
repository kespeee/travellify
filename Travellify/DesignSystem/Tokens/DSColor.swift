import SwiftUI

/// Design-system color tokens. Values sourced from Figma node 93:132
/// (TripListView empty state, dark mode).
///
/// Phase 7 ships dark-only; light-mode variants are deferred.
enum DSColor {
    enum Accent {
        /// #0091FF — primary CTA fill.
        static let primary = Color(
            red: 0x00 / 255.0,
            green: 0x91 / 255.0,
            blue: 0xFF / 255.0
        )
    }

    enum Label {
        /// White — primary label color.
        static let primary = Color.white

        /// rgba(235,235,245,0.7) — secondary label color.
        static let secondary = Color(
            red: 235.0 / 255.0,
            green: 235.0 / 255.0,
            blue: 245.0 / 255.0,
            opacity: 0.7
        )

        /// #F5F5F5 — vibrant primary label, used on top of glass surfaces.
        static let vibrantPrimary = Color(
            red: 0xF5 / 255.0,
            green: 0xF5 / 255.0,
            blue: 0xF5 / 255.0
        )
    }

    enum Background {
        /// #1C1C1E — grouped secondary background.
        static let primary = Color(
            red: 0x1C / 255.0,
            green: 0x1C / 255.0,
            blue: 0x1E / 255.0
        )

        /// #2C2C2E — grouped tertiary background.
        static let tertiary = Color(
            red: 0x2C / 255.0,
            green: 0x2C / 255.0,
            blue: 0x2E / 255.0
        )

        /// #121212 — vibrant tertiary fill (under glass overlays).
        static let vibrantTertiaryFill = Color(
            red: 0x12 / 255.0,
            green: 0x12 / 255.0,
            blue: 0x12 / 255.0
        )
    }

    enum Separator {
        /// rgba(255,255,255,0.17) — non-opaque separator.
        static let nonOpaque = Color.white.opacity(0.17)
    }
}
