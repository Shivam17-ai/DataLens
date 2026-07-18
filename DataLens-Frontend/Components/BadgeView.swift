import SwiftUI

/// Defines the shape and formatting options of a badge component.
enum BadgeStyle {
    /// Circular count indicator (e.g. number of rows, values count)
    case count(Int)
    /// Text label enclosed in pill capsule (e.g. column formats)
    case label(String)
    /// Status descriptor accompanied by colored indicator dots (e.g. active connections)
    case status(text: String, isSuccess: Bool)
}

/// BadgeView represents a highly reusable tag or badge capsule for UI labeling.
struct BadgeView: View {
    let style: BadgeStyle
    let color: Color
    
    init(style: BadgeStyle, color: Color = ColorPalette.accent) {
        self.style = style
        self.color = color
    }
    
    var body: some View {
        switch style {
        case .count(let count):
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 16, minHeight: 16)
                .padding(4)
                .background(Circle().fill(color))
                
        case .label(let label):
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(color.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(color, lineWidth: 0.8)
                )
                
        case .status(let text, let isSuccess):
            HStack(spacing: 5) {
                Circle()
                    .fill(isSuccess ? ColorPalette.success : ColorPalette.warning)
                    .frame(width: 6, height: 6)
                Text(text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(ColorPalette.textPrimary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(ColorPalette.cards.opacity(0.4))
            )
            .overlay(
                Capsule()
                    .stroke(ColorPalette.border, lineWidth: 0.8)
            )
        }
    }
}
