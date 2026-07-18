import SwiftUI

// MARK: - Numeric & Date Formatting Extensions

extension Double {
    /// Formats a double value with a specified number of decimal places.
    func formatted(decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    /// Formats an integer value with comma separators.
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Date {
    /// Formats a date object using standard format styles.
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - Color Hex Initialization

extension Color {
    /// Convenience initializer to resolve colors from hexadecimal strings.
    static func hex(_ string: String) -> Color {
        return Color(hex: string)
    }
}

// MARK: - Layout & Styling View Modifiers

struct CardStyleModifier: ViewModifier {
    var isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .background(ColorPalette.cardGradient)
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(
                color: Color.black.opacity(isHovered ? 0.5 : 0.3),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(
                        isHovered ? ColorPalette.accent : ColorPalette.border,
                        lineWidth: 1.5
                    )
            )
            .offset(y: isHovered ? -4 : 0)
    }
}

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 1.5)
                            .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                        )
                        .clipped()
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    /// Wraps the view in the custom card container styling with hover animations.
    func cardStyle(isHovered: Bool = false) -> some View {
        self.modifier(CardStyleModifier(isHovered: isHovered))
    }
    
    /// Applies a linear shimmering overlay to the view representing active loading states.
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Array Chunking Helpers

extension Array {
    /// Splits an array into chunks of a given maximum size.
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
