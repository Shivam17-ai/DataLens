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

    /// Returns a compact relative string: "just now", "2m ago", "1h ago", "yesterday"
    var relativeLabel: String {
        let secs = Int(-timeIntervalSinceNow)
        if secs < 60  { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
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

// MARK: - Focus Ring Modifier

struct FocusBorderModifier: ViewModifier {
    var isFocused: Bool
    var radius: CGFloat = Constants.Radius.medium
    var color: Color = ColorPalette.accent

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color.opacity(isFocused ? 1.0 : 0.0), lineWidth: 2)
                .shadow(color: color.opacity(isFocused ? 0.4 : 0.0), radius: 4, x: 0, y: 0)
                .animation(.easeInOut(duration: Constants.Animation.instant), value: isFocused)
        )
    }
}

// MARK: - Interactive Scale Modifier

struct InteractiveScaleModifier: ViewModifier {
    var isPressed: Bool
    var scale: CGFloat = 0.97

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: isPressed)
    }
}

// MARK: - Reduce-Motion-Aware Animation

/// Applies a spring animation that collapses to an instant transition
/// when the user has enabled Reduce Motion in System Settings.
struct ReduceMotionAwareAnimationModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var value: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(.spring(response: 0.45, dampingFraction: 0.72), value: value)
        }
    }
}

// MARK: - Shadow Convenience Modifier

struct AppShadowModifier: ViewModifier {
    let definition: Constants.Shadow.Definition

    func body(content: Content) -> some View {
        content.shadow(
            color: definition.color,
            radius: definition.radius,
            x: definition.x,
            y: definition.y
        )
    }
}

// MARK: - High Contrast Border Modifier

struct HighContrastBorderModifier: ViewModifier {
    @Environment(\.accessibilityDifferentiateWithoutColor) var diffWithoutColor
    var radius: CGFloat = Constants.Radius.medium
    var color: Color = ColorPalette.border

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(color, lineWidth: diffWithoutColor ? 2.0 : 1.0)
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Wraps the view in the custom card container styling with hover animations.
    func cardStyle(isHovered: Bool = false) -> some View {
        self.modifier(CardStyleModifier(isHovered: isHovered))
    }

    /// Applies a linear shimmering overlay to the view representing active loading states.
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }

    /// Applies a keyboard-focus ring around the view using accent color.
    func focusBorder(isFocused: Bool, radius: CGFloat = Constants.Radius.medium) -> some View {
        self.modifier(FocusBorderModifier(isFocused: isFocused, radius: radius))
    }

    /// Applies the standard pressed-scale interaction (0.97) with 0.15s easing.
    func interactiveScale(isPressed: Bool) -> some View {
        self.modifier(InteractiveScaleModifier(isPressed: isPressed))
    }

    /// Applies a token-based shadow from the Constants.Shadow system.
    func appShadow(_ definition: Constants.Shadow.Definition) -> some View {
        self.modifier(AppShadowModifier(definition: definition))
    }

    /// Applies a spring animation that automatically degrades to instant
    /// when Reduce Motion is enabled in System Settings.
    func reduceMotionAnimation(value: Bool) -> some View {
        self.modifier(ReduceMotionAwareAnimationModifier(value: value))
    }

    /// Applies a border that thickens automatically under high-contrast mode.
    func highContrastBorder(radius: CGFloat = Constants.Radius.medium) -> some View {
        self.modifier(HighContrastBorderModifier(radius: radius))
    }

    /// Generates a descriptive accessibility label for any chart summary.
    /// - Parameters:
    ///   - chartType: Human-readable name of the chart type.
    ///   - summary: Pre-computed summary sentence (highest value, count, etc.)
    func accessibilityChartLabel(chartType: String, summary: String) -> some View {
        self
            .accessibilityLabel("\(chartType) chart. \(summary)")
            .accessibilityAddTraits(.isStaticText)
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

// MARK: - String Helpers

extension String {
    /// Returns true if this string contains another string, case-insensitively.
    func containsIgnoringCase(_ other: String) -> Bool {
        self.range(of: other, options: .caseInsensitive) != nil
    }
}
