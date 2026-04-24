import SwiftUI

/// Corner-radius tokens.
///
/// `pill` is intentionally large (1000) — used with rectangles where you want
/// fully-rounded "Capsule" geometry but need a numeric radius.
enum DSRadius {
    static let pill: CGFloat = 1000
    static let card: CGFloat = 12
    static let sheet: CGFloat = 16
}
