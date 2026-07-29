import SwiftUI

// MARK: - CardView

/// Reusable styling container representing the premium metallic cards in DataLens.
/// Implements tokenized margins, card-style gradients, hover offsets, and accessibility wrappers.
struct CardView<Content: View>: View {
    let content: Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            content
        }
        .padding(Constants.Spacing.md) // Standard inner padding token
        .background(ColorPalette.cardGradient)
        .cornerRadius(Constants.Radius.medium)
        .shadow(
            color: Color.black.opacity(isHovered ? 0.45 : 0.25),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 6 : 3
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Radius.medium)
                .stroke(
                    isHovered ? ColorPalette.accent : ColorPalette.border,
                    lineWidth: isHovered ? 1.5 : 1.0
                )
        )
        .offset(y: isHovered ? -3 : 0)
        .animation(.easeInOut(duration: Constants.Animation.instant), value: isHovered)
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
    }
}
