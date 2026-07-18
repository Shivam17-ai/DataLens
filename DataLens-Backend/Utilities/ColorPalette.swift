import SwiftUI

/// Semantic application color definitions, supporting dark theme gradients and layout tints.
struct ColorPalette {
    
    // Core Palette Color definitions
    static let background     = Color(hex: "#1A1A2E")
    static let sidebar        = Color(hex: "#16213E")
    static let cards          = Color(hex: "#0F3460")
    static let accent         = Color(hex: "#533483")
    static let textPrimary    = Color(hex: "#E0E0E0")
    static let textSecondary  = Color(hex: "#A0A0B0")
    static let button         = Color(hex: "#533483")
    static let border         = Color(hex: "#2A2A4A")
    static let success        = Color(hex: "#00B4D8")
    static let warning        = Color(hex: "#F59E0B")
    static let error          = Color.red
    static let info           = Color(hex: "#533483")
    
    // Gradient definitions
    static let onboardingBackground = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#1A1A2E"), Color(hex: "#16213E"), Color(hex: "#533483").opacity(0.4)]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#0F3460").opacity(0.95), Color(hex: "#0B2647").opacity(0.98)]),
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let heroGradient = LinearGradient(
        gradient: Gradient(colors: [Color(hex: "#533483").opacity(0.6), Color(hex: "#1A1A2E")]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
