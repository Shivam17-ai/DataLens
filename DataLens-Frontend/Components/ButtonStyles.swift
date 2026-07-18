import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(isHovered ? ColorPalette.accent.opacity(0.85) : ColorPalette.accent)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(ColorPalette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(isHovered ? ColorPalette.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .stroke(ColorPalette.accent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadius)
                    .fill(isHovered ? Color.red.opacity(0.85) : Color.red)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AppColors.textPrimary)
            .padding(8)
            .background(
                Circle()
                    .fill(isHovered ? ColorPalette.accent.opacity(0.2) : ColorPalette.cards.opacity(0.4))
            )
            .overlay(
                Circle()
                    .stroke(isHovered ? ColorPalette.accent : ColorPalette.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - View Helpers for Button Initializers

extension Button {
    /// Styles this button as a standard primary action button.
    func primaryStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    /// Styles this button as a secondary action button with a border.
    func secondaryStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    /// Styles this button as a destructive action button.
    func destructiveStyle() -> some View {
        self.buttonStyle(DestructiveButtonStyle())
    }
    
    /// Styles this button as a circular icon wrapper.
    func iconStyle() -> some View {
        self.buttonStyle(IconButtonStyle())
    }
}
