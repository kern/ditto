import SwiftUI

/// Custom color theme used throughout the app.
extension Color {
    static let dittoAccent = Color.purple
}

extension ShapeStyle where Self == Color {
    static var dittoAccent: Color { Color.dittoAccent }
}
