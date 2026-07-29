import SwiftUI

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.Typography.label)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.medium)
                    .fill(isHovered ? ColorPalette.accent.opacity(0.85) : ColorPalette.accent)
            )
            .opacity(isEnabled ? 1.0 : 0.40)
            .interactiveScale(isPressed: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.Typography.label)
            .foregroundColor(ColorPalette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.medium)
                    .fill(isHovered ? ColorPalette.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.Radius.medium)
                    .stroke(ColorPalette.accent, lineWidth: 1.5)
            )
            .opacity(isEnabled ? 1.0 : 0.40)
            .interactiveScale(isPressed: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Destructive Button Style

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.Typography.label)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.medium)
                    .fill(isHovered ? Color.red.opacity(0.85) : Color.red)
            )
            .opacity(isEnabled ? 1.0 : 0.40)
            .interactiveScale(isPressed: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Ghost Button Style

struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Constants.Typography.label)
            .foregroundColor(ColorPalette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Constants.Radius.small)
                    .fill(isHovered ? ColorPalette.border.opacity(0.4) : Color.clear)
            )
            .opacity(isEnabled ? 1.0 : 0.40)
            .interactiveScale(isPressed: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(ColorPalette.textPrimary)
            .padding(8)
            .background(
                Circle()
                    .fill(isHovered ? ColorPalette.accent.opacity(0.2) : ColorPalette.cards.opacity(0.4))
            )
            .overlay(
                Circle()
                    .stroke(isHovered ? ColorPalette.accent : ColorPalette.border, lineWidth: 1)
            )
            .opacity(isEnabled ? 1.0 : 0.40)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: Constants.Animation.instant), value: configuration.isPressed)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: Constants.Animation.instant)) {
                    isHovered = hovering
                }
            }
            .accessibilityAddTraits(.isButton)
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
    
    /// Styles this button as a transparent ghost action button.
    func ghostStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
    
    /// Styles this button as a circular icon wrapper.
    func iconStyle() -> some View {
        self.buttonStyle(IconButtonStyle())
    }
}
