import SwiftUI

/// Custom color theme used throughout the app.
extension Color {
    /// Primary accent — bright purple in both modes (for tints, badges, highlights).
    static let dittoAccent = Color.purple

    /// Navigation bar background — bright purple in light mode, deep muted purple in dark mode.
    static let dittoNavBar = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.08, blue: 0.38, alpha: 1)
            : UIColor.purple
    })
}

extension ShapeStyle where Self == Color {
    static var dittoAccent: Color { Color.dittoAccent }
    static var dittoNavBar: Color { Color.dittoNavBar }
}
