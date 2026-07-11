import SwiftUI

/// Extension to initialize SwiftUI Color from hex strings
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

/// App-wide styling colors defined in requirements
struct AppColors {
    static let background = Color(hex: "#1A1A2E")
    static let sidebar = Color(hex: "#16213E")
    static let cards = Color(hex: "#0F3460")
    static let accent = Color(hex: "#533483")
    static let textPrimary = Color(hex: "#E0E0E0")
    static let textSecondary = Color(hex: "#A0A0B0")
    static let button = Color(hex: "#533483")
    static let border = Color(hex: "#2A2A4A")
    static let success = Color(hex: "#00B4D8")
}
